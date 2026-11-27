#!/usr/bin/env python3
"""Calendar helper for the Quickshell bar: reads an ICS feed (Proton Calendar "Share via link").

  ical.py sync                         download the feed (URL in ~/.config/qs-bar/calendar-url)
  ical.py status                       {hasUrl, cachedAt, count, name}
  ical.py events <YYYY-MM-DD> <YYYY-MM-DD> [--file f.ics]
                                           events overlapping [from, to) in local time, as JSON
  ical.py seturl                       read a URL from stdin and store it (mode 600)

Only the standard library is used. Repeating events (RRULE, EXDATE, modified occurrences) and
time zones (TZID, UTC) are handled. The feed is read-only: nothing is ever written back.
"""
import json, os, re, sys, tempfile, time, urllib.error, urllib.request
from datetime import date, datetime, timedelta, timezone
from calendar import monthrange

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None

HOME = os.path.expanduser("~")
URL_FILE = os.path.join(HOME, ".config/qs-bar/calendar-url")
CACHE = os.path.join(HOME, ".cache/qs-bar-calendar.ics")
WD = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}


def out(obj, code=0):
    print(json.dumps(obj, ensure_ascii=False))
    sys.exit(code)


def fail(msg):
    out({"error": msg}, 1)


# ── time zones ────────────────────────────────────────────
def local_tz():
    names = []
    if os.environ.get("TZ"):
        names.append(os.environ["TZ"].lstrip(":"))
    try:
        p = os.path.realpath("/etc/localtime")
        if "zoneinfo/" in p:
            names.append(p.split("zoneinfo/", 1)[1])
    except OSError:
        pass
    for n in names:
        try:
            return ZoneInfo(n)
        except Exception:
            continue
    return datetime.now().astimezone().tzinfo


LOCAL = local_tz()


def zone(tzid):
    try:
        return ZoneInfo(tzid)
    except Exception:
        return None


# ── ICS parsing ───────────────────────────────────────────
def unfold(text):
    lines = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)
    return lines


def split_unquoted(s, sep):
    parts, cur, q = [], "", False
    for ch in s:
        if ch == '"':
            q = not q
        if ch == sep and not q:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    parts.append(cur)
    return parts


def parse_line(line):
    head_end = None
    q = False
    for i, ch in enumerate(line):
        if ch == '"':
            q = not q
        elif ch == ":" and not q:
            head_end = i
            break
    if head_end is None:
        return None
    head, value = line[:head_end], line[head_end + 1:]
    bits = split_unquoted(head, ";")
    params = {}
    for b in bits[1:]:
        if "=" in b:
            k, v = b.split("=", 1)
            params[k.upper()] = v.strip('"')
    return bits[0].upper(), params, value


def unescape(v):
    return v.replace("\\n", "\n").replace("\\N", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")


def parse_dt(value, params):
    """-> ('date', date) or ('dt', aware datetime in its own zone)"""
    value = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        return ("date", date(int(value[:4]), int(value[4:6]), int(value[6:8])))
    m = re.fullmatch(r"(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)", value)
    if not m:
        return None
    y, mo, d, h, mi, s = (int(x) for x in m.groups()[:6])
    naive = datetime(y, mo, d, h, mi, s)
    if m.group(7):
        return ("dt", naive.replace(tzinfo=timezone.utc))
    z = zone(params.get("TZID", "")) if params.get("TZID") else None
    return ("dt", naive.replace(tzinfo=z or LOCAL))


def parse_duration(v):
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", v.strip())
    if not m:
        return None
    sign = -1 if m.group(1) == "-" else 1
    w, d, h, mi, s = (int(x or 0) for x in m.groups()[1:])
    return sign * timedelta(weeks=w, days=d, hours=h, minutes=mi, seconds=s)


def parse_events(text):
    """-> (list of event dicts, calendar name)"""
    events, cur, name = [], None, ""
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            cur = {"EXDATE": [], "raw": {}}
        elif line == "END:VEVENT":
            if cur is not None:
                events.append(cur)
            cur = None
        else:
            p = parse_line(line)
            if not p:
                continue
            key, params, value = p
            if key == "X-WR-CALNAME" and cur is None:
                name = unescape(value)
            if cur is None:
                continue
            if key == "EXDATE":
                for part in value.split(","):
                    dt = parse_dt(part, params)
                    if dt:
                        cur["EXDATE"].append(dt)
            elif key in ("DTSTART", "DTEND", "RECURRENCE-ID"):
                cur[key] = parse_dt(value, params)
            elif key == "DURATION":
                cur[key] = parse_duration(value)
            elif key in ("SUMMARY", "LOCATION", "DESCRIPTION"):
                cur[key] = unescape(value)
            elif key in ("UID", "STATUS", "RRULE"):
                cur[key] = value.strip()
    return events, name


# ── recurrence ────────────────────────────────────────────
def parse_rrule(s):
    r = {}
    for part in s.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            r[k.upper()] = v
    r["INTERVAL"] = max(1, int(r.get("INTERVAL", 1) or 1))
    if "COUNT" in r:
        r["COUNT"] = int(r["COUNT"])
    byday = []
    for tok in r.get("BYDAY", "").split(","):
        m = re.fullmatch(r"([+-]?\d+)?(MO|TU|WE|TH|FR|SA|SU)", tok.strip())
        if m:
            byday.append((int(m.group(1)) if m.group(1) else None, WD[m.group(2)]))
    r["_byday"] = byday
    r["_bymonthday"] = [int(x) for x in r.get("BYMONTHDAY", "").split(",") if x.strip()]
    r["_bymonth"] = [int(x) for x in r.get("BYMONTH", "").split(",") if x.strip()]
    r["_wkst"] = WD.get(r.get("WKST", "MO"), 0)
    return r


def month_days(y, m, rule, start_day):
    """days of month (y, m) selected by BYMONTHDAY / BYDAY, defaulting to the start's day"""
    n = monthrange(y, m)[1]
    days = set()
    if rule["_bymonthday"]:
        for d in rule["_bymonthday"]:
            dd = d if d > 0 else n + 1 + d
            if 1 <= dd <= n:
                days.add(dd)
    elif rule["_byday"]:
        for ordn, wd in rule["_byday"]:
            matches = [d for d in range(1, n + 1) if date(y, m, d).weekday() == wd]
            if ordn is None:
                days.update(matches)
            else:
                idx = ordn - 1 if ordn > 0 else ordn
                if -len(matches) <= idx < len(matches):
                    days.add(matches[idx])
    else:
        if start_day <= n:
            days.add(start_day)
    return sorted(days)


def occurrence_dates(rule, start, limit):
    """yield dates (>= start) of the recurrence, in order, until `limit` (a date) or the rule ends"""
    freq, step = rule.get("FREQ", ""), rule["INTERVAL"]
    until = None
    if "UNTIL" in rule:
        u = parse_dt(rule["UNTIL"], {})
        if u:
            until = u[1] if u[0] == "date" else u[1].astimezone(LOCAL).date()
    count, produced = rule.get("COUNT"), 0

    def ok(d):
        if rule["_bymonth"] and d.month not in rule["_bymonth"] and freq in ("DAILY", "WEEKLY"):
            return False
        if freq == "DAILY":
            if rule["_byday"] and d.weekday() not in [w for _, w in rule["_byday"]]:
                return False
            if rule["_bymonthday"]:
                n = monthrange(d.year, d.month)[1]
                if d.day not in [x if x > 0 else n + 1 + x for x in rule["_bymonthday"]]:
                    return False
        return True

    def emit_filter(d):
        nonlocal produced
        if d < start:
            return None
        if until and d > until:
            raise StopIteration
        produced += 1
        if count and produced > count:
            raise StopIteration
        return d

    iterations = 0
    try:
        if freq == "DAILY":
            k = 0
            while True:
                d = start + timedelta(days=k * step)
                if d > limit + timedelta(days=1) or iterations > 20000:
                    return
                iterations += 1
                k += 1
                if ok(d):
                    r = emit_filter(d)
                    if r:
                        yield r
        elif freq == "WEEKLY":
            wds = sorted({w for _, w in rule["_byday"]} or {start.weekday()}, key=lambda w: (w - rule["_wkst"]) % 7)
            week0 = start - timedelta(days=(start.weekday() - rule["_wkst"]) % 7)
            k = 0
            while True:
                ws = week0 + timedelta(days=7 * step * k)
                if ws > limit + timedelta(days=1) or iterations > 5000:
                    return
                iterations += 1
                k += 1
                for w in wds:
                    d = ws + timedelta(days=(w - rule["_wkst"]) % 7)
                    if rule["_bymonth"] and d.month not in rule["_bymonth"]:
                        continue
                    r = emit_filter(d)
                    if r:
                        yield r
        elif freq == "MONTHLY":
            k = 0
            while True:
                total = start.year * 12 + (start.month - 1) + k * step
                y, m = total // 12, total % 12 + 1
                if date(y, m, 1) > limit + timedelta(days=1) or iterations > 2000:
                    return
                iterations += 1
                k += 1
                if rule["_bymonth"] and m not in rule["_bymonth"]:
                    continue
                for dd in month_days(y, m, rule, start.day):
                    r = emit_filter(date(y, m, dd))
                    if r:
                        yield r
        elif freq == "YEARLY":
            k = 0
            while True:
                y = start.year + k * step
                if date(y, 1, 1) > limit + timedelta(days=1) or iterations > 500:
                    return
                iterations += 1
                k += 1
                for m in (rule["_bymonth"] or [start.month]):
                    for dd in month_days(y, m, rule, start.day):
                        r = emit_filter(date(y, m, dd))
                        if r:
                            yield r
    except StopIteration:
        return


# ── expansion into occurrences ────────────────────────────
def key_of(dt):
    kind, v = dt
    return ("d", v) if kind == "date" else ("t", int(v.timestamp()))


def to_local_naive(dt):
    return dt.astimezone(LOCAL).replace(tzinfo=None)


def expand(events, win_start, win_end):
    """events overlapping [win_start, win_end) (naive local datetimes) -> list of output dicts"""
    overrides = {}
    for e in events:
        if "RECURRENCE-ID" in e and e.get("UID"):
            overrides[(e["UID"], key_of(e["RECURRENCE-ID"]))] = e

    result = []

    def add(e, start, end, all_day):
        if e.get("STATUS", "").upper() == "CANCELLED":
            return
        if all_day:
            s, en = datetime.combine(start, datetime.min.time()), datetime.combine(end, datetime.min.time())
        else:
            s, en = start, end
        if en <= win_start and s < win_start or s >= win_end:
            return
        if en < win_start or (en == win_start and s != en):
            return
        result.append({
            "title": e.get("SUMMARY", "(no title)"),
            "start": start.isoformat() if all_day else start.strftime("%Y-%m-%dT%H:%M"),
            "end": end.isoformat() if all_day else end.strftime("%Y-%m-%dT%H:%M"),
            "allDay": all_day,
            "location": e.get("LOCATION", ""),
            "desc": (e.get("DESCRIPTION", "") or "")[:400],
            "uid": e.get("UID", ""),
        })

    for e in events:
        if "DTSTART" not in e or e.get("DTSTART") is None:
            continue
        kind, ds = e["DTSTART"]
        all_day = kind == "date"
        # length
        if "DTEND" in e and e["DTEND"]:
            ek, de = e["DTEND"]
            length = (de - ds) if ek == kind else timedelta(0)
        elif e.get("DURATION"):
            length = e["DURATION"]
        else:
            length = timedelta(days=1) if all_day else timedelta(0)
        if all_day and length < timedelta(days=1):
            length = timedelta(days=1)

        if "RRULE" not in e:
            if all_day:
                add(e, ds, ds + length, True)
            else:
                add(e, to_local_naive(ds), to_local_naive(ds + length), False)
            continue

        rule = parse_rrule(e["RRULE"])
        ex = {key_of(x) for x in e["EXDATE"]}
        limit = win_end.date()
        start_date = ds if all_day else ds.replace(tzinfo=None).date()
        t0 = None if all_day else ds.replace(tzinfo=None).time()
        for d in occurrence_dates(rule, start_date, limit):
            if all_day:
                occ_key = ("d", d)
                if occ_key in ex or (e.get("UID"), occ_key) in overrides:
                    continue
                add(e, d, d + length, True)
            else:
                occ = datetime.combine(d, t0).replace(tzinfo=ds.tzinfo)
                occ_key = ("t", int(occ.timestamp()))
                if occ_key in ex or (e.get("UID"), occ_key) in overrides:
                    continue
                add(e, to_local_naive(occ), to_local_naive(occ + length), False)
            if d > limit + timedelta(days=1):
                break
    result.sort(key=lambda r: (r["start"], r["title"]))
    return result


# ── commands ──────────────────────────────────────────────
def read_url():
    try:
        for line in open(URL_FILE):
            line = line.strip()
            if line and not line.startswith("#"):
                return line
    except OSError:
        pass
    return ""


def cmd_seturl():
    url = sys.stdin.read().strip()
    if not re.match(r"^(https?|webcal)://", url):
        fail("that does not look like a calendar link")
    os.makedirs(os.path.dirname(URL_FILE), exist_ok=True)
    fd = os.open(URL_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(url + "\n")
    out({"ok": True})


def cmd_sync():
    url = read_url()
    if not url:
        fail("no-url")
    url = re.sub(r"^webcal://", "https://", url)
    req = urllib.request.Request(url, headers={"User-Agent": "qs-bar-calendar/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            body = r.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        fail("calendar server answered HTTP %d" % e.code)
    except Exception as e:
        fail("could not download the calendar (%s)" % type(e).__name__)
    if "BEGIN:VCALENDAR" not in body[:2000]:
        fail("that link did not return a calendar file")
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE))
    with os.fdopen(fd, "w") as f:
        f.write(body)
    os.chmod(tmp, 0o600)
    os.replace(tmp, CACHE)
    events, name = parse_events(body)
    out({"ok": True, "count": len(events), "name": name})


def cmd_status():
    info = {"hasUrl": bool(read_url()), "cachedAt": 0, "count": 0, "name": ""}
    try:
        info["cachedAt"] = int(os.path.getmtime(CACHE))
        events, name = parse_events(open(CACHE, encoding="utf-8", errors="replace").read())
        info["count"], info["name"] = len(events), name
    except OSError:
        pass
    out(info)


def cmd_events(args):
    path = CACHE
    if "--file" in args:
        i = args.index("--file")
        path = args[i + 1]
        args = args[:i] + args[i + 2:]
    if len(args) < 2:
        fail("usage: ical.py events <from> <to>")
    try:
        ws = datetime.strptime(args[0], "%Y-%m-%d")
        we = datetime.strptime(args[1], "%Y-%m-%d")
    except ValueError:
        fail("dates must look like 2026-10-31")
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        fail("not-synced")
    events, _ = parse_events(text)
    out(expand(events, ws, we))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "sync":
        cmd_sync()
    elif cmd == "status":
        cmd_status()
    elif cmd == "seturl":
        cmd_seturl()
    elif cmd == "events":
        cmd_events(sys.argv[2:])
    else:
        fail("usage: ical.py sync|status|seturl|events <from> <to>")
