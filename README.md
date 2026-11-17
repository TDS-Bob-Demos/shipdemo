# IBM Bob for IBM i Demo: "Truck 14 Can't Leave"

A small metals-distributor shipping module on PUB400 that you troubleshoot and document live with IBM Bob.


- Every object starts with `SHP`, so it groups together even if `ANNIEROME2` has other things in it. Before building, run `WRKOBJ ANNIEROME2/SHP*` to make sure nothing collides.
- Source goes in classic source physical files in `ANNIEROME2` (`QDDSSRC`, `QRPGLESRC`, `QCLLESRC`, `QSQLSRC`), which looks like a real legacy shop.
- Optional staging: upload the folder to the IFS at `/home/ANNIEROME/shipdemo`, then copy it into the members (see `BUILD.txt`).

## Objects

| Object | Type | Source member | What it is |
|---|---|---|---|
| SHPITEM | PF | QDDSSRC | Item master (UOM, weight per unit, heat #) |
| SHPMTR | PF | QDDSSRC | Mill test reports on file, by heat # (scanned flag + path) |
| SHPORDH | PF | QDDSSRC | Order header. `OHSRC = 'WEB'` is the web order-entry front end |
| SHPORDD | PF | QDDSSRC | Order lines |
| SHPLOAD | PF | QDDSSRC | Truck loads: max weight, total weight, status, message |
| SHPORDL1 | LF | QDDSSRC | Orders by load # |
| SHPCONFD | DSPF | QDDSSRC | Green-screen dock confirmation screen |
| SHPCONF | CLLE | QCLLESRC | Dock entry point. Shows the screen, calls SHPVAL |
| SHPVAL | RPGLE | QRPGLESRC | Ship validation: totals weight, checks MTRs, holds or releases the load |
| SHPWGT | RPGLE | QRPGLESRC | Converts quantity to pounds by UOM. **Contains the bug** |
| SHPWGTFX | RPGLE (source only) | QRPGLESRC | Backup of the fixed version. Never compile it unless it's an emergency |
| SHPDATA / SHPRESET | SQL | QSQLSRC | Sample data / reset load status |

Call chain: `SHPCONF → SHPVAL → SHPWGT`, with SHPVAL reading SHPLOAD, SHPORDL1, SHPORDD, SHPITEM, and SHPMTR.

The RPG is **fixed-format RPG IV** (H/F/D/C specs, `*ENTRY PLIST`, `CALL`/`PARM`, numbered indicators, `MULT`/`Z-ADD`), with no comments, cryptic names, and no documentation on purpose. That mirrors the customer's situation.

## The planted bug

`SHPWGT` handles UOMs `FT`, `LB`, and `SHT` in a `SELECT`/`WHENEQ` block. CWT (hundredweight) items were added to the item master later, but no `CWT` branch was ever added. CWT lines fall into `OTHER`, which does `MULT ITWGTU` and then `MULT 100`. Rebar item `RB4` has `ITWGTU = 100` (lb per cwt), so 12 cwt becomes **120,000 lb** instead of 1,200.

| Load | Actual weight | Program computes | Result |
|---|---|---|---|
| 14 (TRK14) | 30,221 lb | **149,021 lb** | HELD: exceeds max weight (**bug**) |
| 15 (TRK15) | 11,634 lb | 11,634 lb | RELEASED |
| 16 (TRK16) | 6,480 lb | 6,480 lb | HELD: no MTR for heat H24-6118 (a **legitimate** hold) |

**The fix:** add a CWT branch before `OTHER` (see `SHPWGTFX.rpgle`):
```
     C     ITUOM         WHENEQ    'CWT'
     C     pQty          MULT      ITWGTU        pWgt
```

Load 16 is your credibility moment. Bob should tell the two holds apart: one is a code defect, the other is a business rule doing its job (the MTR hasn't been scanned yet).

---

## Run of show (~30 min)

### Part 1: Targeted troubleshooting (15 min)

**1. The incident (2 min).** In a 5250 session, run `CALL SHPCONF`, enter `14`, and press Enter. The screen shows a red HELD status and "LOAD 14 HELD - EXCEEDS MAX WEIGHT."
> "It's 4:30, the driver's waiting, dispatch swears the order is about 30,000 pounds, and nobody has opened this code in years."

**2. Find where the hold comes from (3 min).** Bob prompt:
> Our dock program SHPCONF in library ANNIEROME2 is holding load 14 with "EXCEEDS MAX WEIGHT", but the orders on that load only weigh about 30,000 lb against a 48,000 lb truck limit. Trace where this hold is decided and what programs and files are involved.

Expected: SHPCONF → SHPVAL (sets HELD at `pTot WHENGT LDMAXW`) → SHPWGT (weight per line).

**3. Plain-language explanation (3 min).** Bob prompt:
> Explain what SHPVAL and SHPWGT do in plain business language, as if you were explaining it to a shipping supervisor who doesn't read code.

**4. Root cause (3 min).** Bob prompt:
> Which line on load 14 is causing the inflated weight? Write me a SQL query I can run to see every line on load 14 with its unit of measure, quantity, and the weight SHPWGT would calculate.

Run it (this moment is for Paula):
```sql
SELECT d.ODORD, d.ODLINE, d.ODITEM, i.ITUOM, d.ODQTY, i.ITWGTU
  FROM ANNIEROME2.SHPORDD d
  JOIN ANNIEROME2.SHPORDH h ON h.OHORD = d.ODORD
  JOIN ANNIEROME2.SHPITEM i ON i.ITITEM = d.ODITEM
 WHERE h.OHLOAD = 14;
```
Expected: `RB4`, UOM `CWT`, which has no branch in SHPWGT, so it falls to `OTHER` and gets ×100 twice.

**5. Fix and verify (4 min).** Bob prompt:
> Fix SHPWGT so CWT items calculate correctly. Keep the change minimal, keep it in fixed format, and explain it.

Save, then run `CRTBNDRPG PGM(ANNIEROME2/SHPWGT) SRCFILE(ANNIEROME2/QRPGLESRC) SRCMBR(SHPWGT)` and `CALL SHPCONF` again with load 14. You should see **RELEASED** in green, 30,221 lb, "BOL SENT TO DOCK1." The truck leaves.

Optional credibility beat: run load 16 and ask Bob, "Is load 16's hold the same bug?" It should say no: the MTR for heat H24-6118 isn't scanned (`MTSCAN = 'N'`).

### Part 2: Code understanding and documentation (12 min)

**1. Understand dashboard (4 min).** Point it at `ANNIEROME2` and walk through the programs, files, and call graph, plus which programs read or update which files.

**2. Program documentation (3 min).** Bob prompt:
> Generate documentation for SHPVAL: purpose, parameters, files used (read vs. update), business rules, and a glossary of every field it uses with a plain-English meaning.

**3. Onboarding guide (2 min).** Bob prompt:
> Write an onboarding guide to the shipping module for a new developer: how a load moves from order entry to release, which objects are involved, and where the risky logic lives.

**4. Fit-gap / modernization starter (3 min).** Bob prompt:
> List every business rule in this shipping module, which tables the web order-entry front end depends on (OHSRC = 'WEB'), and what a modernization or ERP fit-gap would need to preserve.

**Close:** "This took minutes for six objects. Imagine running it across every program on your AS/400. That's your institutional knowledge, written down."

---

## Rolling back after a demo run

After the demo you will have (a) Bob's fix saved into the `SHPWGT` source member and (b) load statuses changed from `OPEN` to `HELD`/`RELEASED`. Both must be undone before the next run.

### 1. Reset the data

This sets every load back to `OPEN` with zero weight and clears the status messages:

```
RUNSQLSTM SRCFILE(ANNIEROME2/QSQLSRC) SRCMBR(SHPRESET) COMMIT(*NONE)
```

### 2. Restore the buggy SHPWGT source

If the original source files are still on the IFS:

```
CPYFRMSTMF FROMSTMF('/home/ANNIEROME/shipdemo/SHPWGT.rpgle') TOMBR('/QSYS.LIB/ANNIEROME2.LIB/QRPGLESRC.FILE/SHPWGT.MBR') MBROPT(*REPLACE)
```

If the IFS copy is gone, open the `SHPWGT` member in Bob's editor, undo Bob's CWT branch (delete the two added `WHENEQ`/`MULT` lines), and save.

### 3. Recompile the buggy version

```
CRTBNDRPG PGM(ANNIEROME2/SHPWGT) SRCFILE(ANNIEROME2/QRPGLESRC) SRCMBR(SHPWGT) DBGVIEW(*SOURCE)
```

### 4. Verify

Run `CALL SHPCONF` and enter load `14`. You should see **HELD** with weight **149,021** — the bug is back and the demo is ready.

### Quick-reference (all three steps, copy-paste)

```
RUNSQLSTM SRCFILE(ANNIEROME2/QSQLSRC) SRCMBR(SHPRESET) COMMIT(*NONE)
CPYFRMSTMF FROMSTMF('/home/ANNIEROME/shipdemo/SHPWGT.rpgle') TOMBR('/QSYS.LIB/ANNIEROME2.LIB/QRPGLESRC.FILE/SHPWGT.MBR') MBROPT(*REPLACE)
CRTBNDRPG PGM(ANNIEROME2/SHPWGT) SRCFILE(ANNIEROME2/QRPGLESRC) SRCMBR(SHPWGT) DBGVIEW(*SOURCE)
```

---

## Before each run
1. Follow the rollback steps above (or confirm they were already done).
2. Run the prompts once beforehand so you know roughly what Bob will say.

**If something breaks live:** `CRTBNDRPG PGM(ANNIEROME2/SHPWGT) SRCFILE(ANNIEROME2/QRPGLESRC) SRCMBR(SHPWGTFX)`
