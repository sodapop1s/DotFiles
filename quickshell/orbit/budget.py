#!/usr/bin/env python3
"""Budget helper for the School tab's Money page (Python standard library only).

  budget.py summary [YYYY-MM]    -> {month, months, spent, income, byCat:[{cat, spent, limit}], recent:[...], uncategorised, daysLeft, ...}
  budget.py add "<text>"         -> "$12.50 coffee", "12.5 chipotle lunch", "+200 paycheck"  (adds today's transaction)
  budget.py import <file.csv>    -> import a Bank of America (or similar) CSV export; duplicates are skipped
  budget.py scan                 -> CSV files in ~/Downloads that look like bank exports and have not been imported
  budget.py recat <id> <cat>     -> change a transaction's category (and remember it for that merchant)
  budget.py limit <cat> <amount> -> monthly budget for a category (0 removes it)
  budget.py drop <id>            -> delete a transaction
  budget.py cats                 -> category names

Everything stays on this computer in ~/.local/share/qs-bar/budget.json. There is no bank login: you download the CSV from
your bank's website yourself (Accounts -> Activity -> Download) and import it here.
QS_BUDGET_FILE and QS_DOWNLOADS override the locations (testing).
"""
import csv, hashlib, json, os, re, sys, time
from datetime import date, datetime

HOME = os.path.expanduser("~")
DATA = os.environ.get("QS_BUDGET_FILE") or os.path.join(HOME, ".local/share/qs-bar/budget.json")
DOWNLOADS = os.environ.get("QS_DOWNLOADS") or os.path.join(HOME, "Downloads")

DEFAULT_RULES = {
    "Food": "chipotle starbucks coffee dunkin doordash ubereats grubhub mcdonald subway pizza taco burger wendy chick-fil panera restaurant cafe diner bakery boba sushi wingstop popeyes kfc",
    "Groceries": "kroger publix walmart aldi trader whole foods safeway costco grocery market sprouts heb",
    "Transport": "uber lyft shell chevron exxon gas parking transit marta metro bp sunoco",
    "Subscriptions": "spotify netflix hulu disney apple.com/bill google one openai claude anthropic youtube icloud patreon adobe github",
    "School": "bookstore chegg textbook coursehero tuition printing pearson wiley",
    "Housing": "rent landlord apartment lease utilities electric water internet comcast xfinity",
    "Shopping": "amazon target best buy ebay etsy nike zara shein",
    "Health": "cvs walgreens pharmacy clinic dental gym",
    "Fun": "steam games cinema movie amc concert ticketmaster bar pub",
    "Transfer": "payment thank transfer zelle venmo cash app online banking mobile banking autopay",
}
INCOME_WORDS = "payroll direct dep deposit paycheck refund scholarship stipend interest"

def out(obj):
    print(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))

def fail(msg):
    out({"error": msg}); sys.exit(1)

def load():
    try:
        with open(DATA, encoding="utf-8") as f:
            d = json.load(f)
    except (OSError, ValueError):
        d = {}
    d.setdefault("tx", []); d.setdefault("limits", {}); d.setdefault("rules", {}); d.setdefault("imported", [])
    return d

def save(d):
    os.makedirs(os.path.dirname(DATA), exist_ok=True)
    tmp = DATA + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, DATA)

def categorise(d, desc, amount):
    low = desc.lower()
    for kw, cat in d["rules"].items():          # your own corrections first
        if kw in low:
            return cat
    for cat, words in DEFAULT_RULES.items():
        for w in words.split():
            if w in low:
                return cat
    if amount > 0 and any(w in low for w in INCOME_WORDS.split()):
        return "Income"
    return "Income" if amount > 0 else "Other"

def tid(day, amount, desc):
    return hashlib.sha1(("%s|%.2f|%s" % (day, amount, desc[:40])).encode()).hexdigest()[:10]

def money(s):
    s = s.strip().replace("$", "").replace(",", "")
    neg = s.startswith("(") and s.endswith(")")
    s = s.strip("()")
    v = float(s)
    return -abs(v) if neg else v

def clean(desc):
    desc = re.sub(r"\s+", " ", desc).strip()
    desc = re.sub(r"\b(DES|ID|INDN|CO ID|PPD|WEB|CCD):.*$", "", desc).strip()
    return desc[:48]

def parse_date(s):
    s = s.strip()
    for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%m/%d/%y"):
        try:
            return datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            pass
    return None

def read_csv(path):
    """Bank of America checking/savings ('Date,Description,Amount,Running Bal.') and credit card ('Posted Date,...,Payee,...,Amount') exports."""
    with open(path, newline="", encoding="utf-8-sig", errors="replace") as f:
        rows = list(csv.reader(f))
    head = None
    for i, r in enumerate(rows):
        cells = [c.strip().lower() for c in r]
        if cells[:1] in (["date"], ["posted date"], ["transaction date"]) and ("amount" in cells):
            head = i; break
    if head is None:
        fail("that does not look like a bank export (no Date/Amount header)")
    cols = [c.strip().lower() for c in rows[head]]
    di = 0
    ai = cols.index("amount")
    ni = next((cols.index(k) for k in ("description", "payee", "name", "merchant") if k in cols), 1)
    res = []
    for r in rows[head + 1:]:
        if len(r) <= max(ai, ni):
            continue
        day = parse_date(r[di])
        if not day:
            continue
        try:
            amt = money(r[ai])
        except ValueError:
            continue
        res.append((day, amt, clean(r[ni])))
    return res

def month_of(day):
    return day[:7]

def cmd_add(d, text):
    text = (text or "").strip()
    m = re.match(r"^([+-]?)\$?\s*(\d+(?:[.,]\d{1,2})?)\s*(.*)$", text)
    if not m:
        fail("write it like  $12.50 coffee")
    sign, num, desc = m.groups()
    amt = float(num.replace(",", "."))
    amt = amt if sign == "+" else -amt
    desc = clean(desc) or "(no description)"
    day = date.today().isoformat()
    t = {"id": tid(day, amt, desc + str(time.time())), "date": day, "amt": amt, "desc": desc, "cat": categorise(d, desc, amt), "src": "manual"}
    d["tx"].append(t); save(d)
    out({"ok": True, "tx": t})

def cmd_import(d, path):
    path = os.path.realpath(os.path.expanduser(path or ""))
    if not (path.startswith(HOME + os.sep) and path.lower().endswith(".csv") and os.path.isfile(path)):
        fail("pick a .csv file inside your home folder")
    if os.path.getsize(path) > 5 * 1024 * 1024:
        fail("that file is too big to be a bank export")
    have = {t["id"] for t in d["tx"]}
    added = skipped = 0
    for day, amt, desc in read_csv(path):
        i = tid(day, amt, desc)
        if i in have:
            skipped += 1; continue
        d["tx"].append({"id": i, "date": day, "amt": amt, "desc": desc, "cat": categorise(d, desc, amt), "src": "csv"})
        have.add(i); added += 1
    h = hashlib.sha1(open(path, "rb").read()).hexdigest()[:12]
    if h not in d["imported"]:
        d["imported"].append(h)
    save(d)
    out({"ok": True, "added": added, "skipped": skipped})

def cmd_scan(d):
    found = []
    try:
        names = os.listdir(DOWNLOADS)
    except OSError:
        names = []
    for n in names:
        p = os.path.join(DOWNLOADS, n)
        if not n.lower().endswith(".csv") or not os.path.isfile(p) or os.path.getsize(p) > 5 * 1024 * 1024:
            continue
        try:
            h = hashlib.sha1(open(p, "rb").read()).hexdigest()[:12]
            if h in d["imported"]:
                continue
            rows = read_csv_quiet(p)
        except Exception:
            continue
        if rows:
            found.append({"path": p, "name": n, "count": rows, "mtime": int(os.path.getmtime(p))})
    found.sort(key=lambda x: -x["mtime"])
    out(found[:6])

def read_csv_quiet(p):
    with open(p, newline="", encoding="utf-8-sig", errors="replace") as f:
        rows = list(csv.reader(f))
    for i, r in enumerate(rows):
        cells = [c.strip().lower() for c in r]
        if cells[:1] in (["date"], ["posted date"], ["transaction date"]) and "amount" in cells:
            return max(0, len(rows) - i - 1)
    return 0

def cmd_summary(d, month):
    today = date.today()
    month = month or today.strftime("%Y-%m")
    tx = [t for t in d["tx"] if month_of(t["date"]) == month]
    spend = {}; income = 0.0
    for t in tx:
        if t["cat"] == "Transfer":
            continue
        if t["amt"] < 0:
            spend[t["cat"]] = spend.get(t["cat"], 0) - t["amt"]
        elif t["cat"] == "Income" or t["amt"] > 0:
            income += t["amt"]
    cats = sorted(set(spend) | {c for c, v in d["limits"].items() if v > 0})
    by = [{"cat": c, "spent": round(spend.get(c, 0), 2), "limit": d["limits"].get(c, 0)} for c in cats]
    by.sort(key=lambda x: -x["spent"])
    total_limit = sum(v for v in d["limits"].values() if v > 0)
    spent = round(sum(spend.values()), 2)
    first = datetime.strptime(month + "-01", "%Y-%m-%d").date()
    nxt = date(first.year + (first.month // 12), first.month % 12 + 1, 1)
    days_in = (nxt - first).days
    left = max(0, (nxt - today).days) if first.year == today.year and first.month == today.month else 0
    months = sorted({month_of(t["date"]) for t in d["tx"]} | {today.strftime("%Y-%m")}, reverse=True)
    recent = sorted(d["tx"], key=lambda t: (t["date"], t["id"]), reverse=True)
    recent = [t for t in recent if month_of(t["date"]) == month][:14]
    out({"month": month, "months": months, "spent": spent, "income": round(income, 2), "byCat": by, "limit": total_limit,
         "left": round(total_limit - spent, 2) if total_limit else None, "daysLeft": left, "daysIn": days_in,
         "perDay": round((total_limit - spent) / left, 2) if total_limit and left else None,
         "recent": recent, "uncategorised": len([t for t in tx if t["cat"] == "Other"]), "count": len(tx),
         "cats": sorted(set(DEFAULT_RULES) | {"Income", "Other"} | set(d["limits"]))})

def cmd_recat(d, i, cat):
    cat = re.sub(r"[^A-Za-z0-9 &/-]", "", cat or "").strip()[:24]
    if not cat:
        fail("pick a category")
    for t in d["tx"]:
        if t["id"] == i:
            t["cat"] = cat
            word = next((w for w in re.findall(r"[a-z][a-z0-9.-]{3,}", t["desc"].lower())), "")
            if word and cat not in ("Income",):
                d["rules"][word] = cat
                for u in d["tx"]:            # apply the same merchant to older rows still in "Other"
                    if u["cat"] == "Other" and word in u["desc"].lower():
                        u["cat"] = cat
            save(d); out({"ok": True}); return
    fail("no such transaction")

def cmd_limit(d, cat, amount):
    cat = re.sub(r"[^A-Za-z0-9 &/-]", "", cat or "").strip()[:24]
    try:
        v = float(amount)
    except (TypeError, ValueError):
        fail("give an amount")
    if not cat:
        fail("pick a category")
    if v <= 0:
        d["limits"].pop(cat, None)
    else:
        d["limits"][cat] = round(v, 2)
    save(d); out({"ok": True})

def main(a):
    d = load()
    c = a[0] if a else ""
    if c == "summary": cmd_summary(d, a[1] if len(a) > 1 else "")
    elif c == "add": cmd_add(d, a[1] if len(a) > 1 else "")
    elif c == "import": cmd_import(d, a[1] if len(a) > 1 else "")
    elif c == "scan": cmd_scan(d)
    elif c == "recat": cmd_recat(d, a[1] if len(a) > 1 else "", a[2] if len(a) > 2 else "")
    elif c == "limit": cmd_limit(d, a[1] if len(a) > 1 else "", a[2] if len(a) > 2 else "")
    elif c == "drop":
        d["tx"] = [t for t in d["tx"] if t["id"] != (a[1] if len(a) > 1 else "")]; save(d); out({"ok": True})
    elif c == "cats": out(sorted(set(DEFAULT_RULES) | {"Income", "Other"}))
    else: fail("usage: budget.py summary|add|import|scan|recat|limit|drop|cats")

if __name__ == "__main__":
    main(sys.argv[1:])
