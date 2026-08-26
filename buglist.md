# HydroGNSS_Extraction — Bug List

Status legend: **FIXED** · **OPEN** · **SKIPPED** (deliberately not applied) · **NOT A BUG** (investigated, no defect)

---

## HIGH severity

*(none — see the note on BUG 1)*

---

## MEDIUM severity

### BUG 2 — `DataOutputRootPath` not validated before the run starts — **FIXED**
**File:** `HydroGNSS_extract.m` (check added next to the logs check, ~line 150)

The output directory was never checked before processing began, so a wrong path
threw at the final `save()` — after the whole extraction had completed. Observed
in practice on the everglades run.

Added an existence check at startup so a bad path fails immediately:
```matlab
if ~exist(char(DataOutputRootPath), 'dir')
        throw(MException('INPUT:ERROR', "Output directory does not exist: " + string(DataOutputRootPath)))
end
```

---

### BUG 3 — `LogsOutputRootPath` not validated, with wrong error message — **FIXED**
**File:** `HydroGNSS_extract.m` lines 147–149 (before the fix)

The logs folder check raised *"Cannot find configuration file"* — a misleading
message that sent debugging in the wrong direction. `exist()` was also called
with one argument, so it could match a variable rather than a directory.
Observed in practice.

Now reports the real cause and restricts the check to directories:
```matlab
if ~exist(char(LogsOutputRootPath), 'dir')
        throw(MException('INPUT:ERROR', "Logs directory does not exist: " + string(LogsOutputRootPath)))
end
```

---

### BUG 4 — Land filter (`LandType < 210`) silently discarded — **SKIPPED**
**File:** `HydroGNSS_extract.m` (land-filter block, ~line 709)

`LandSPindx = find(Landtypesub < 210)` is computed from the metadata land type,
then unconditionally overwritten by the sea-mask result, so only the mask decides.
The intended combination was written but left commented out:
```matlab
% LandSPindx = intersect(LandSPindx, validIdx(~isOceanValid));
LandSPindx = validIdx(~isOceanValid);
```

**Not applied — this one changes scientific output.** After the fix a point must
be land by *both* criteria, so points the mask calls land but the metadata calls
water (210) or snow/ice (220) would be dropped. The existing
`Original / Mask-only / Combined land count` printout shows the size of the
difference. Needs a deliberate call before applying.

---

### BUG 6 — DDM file open had no error handling — **FIXED**
**File:** `read_L1Bproduct.m` (DDM open, ~line 173)

A corrupt or truncated `DDMs.nc` threw `NC_EHDFERR` straight out of
`netcdf.open` and killed the run. Observed in practice: a bad DDM file
mid-timeseries aborted a run after a week of data had already been processed.

The DDM open and its group-id walk are now wrapped in `try/catch`. A bad DDM
file logs a warning, sets `readDDMsinglefile="No"`, and the block continues with
metadata only. See also LEAK 1, which is the other half of this failure.

---

## LOW severity

### BUG 1 — dead `sub2ind` line — **FIXED** *(was misdiagnosed as HIGH)*
**File:** `HydroGNSS_extract.m` lines 746–747 (before the fix)

```matlab
linearIdx = sub2ind([nRows, nCols], idxRows, idxCols);   % wrong, and discarded
linearIdx = sub2ind([nCols, nRows ], idxCols, idxRows);  % correct, and wins
```

**Correction to the original entry:** the *second* line is the correct one, not
the first. `easeconv_grid3` returns `[column, row]` (`easeconv_grid3.m:69-70`) and
`[nCols,nRows] = size(seaMask)` (`HydroGNSS_extract.m:65`), so dimension 1 is
indexed by `idxCols`. Because line 747 overwrites line 746, the surviving value
was always right — **no output was ever misclassified.** Line 746 was dead code
computing a discarded wrong value. Removed it and kept the correct call.

---

### BUG 5 — globals not cleared between runs — **NOT A BUG**
**File:** `read_L1Bproduct.m` line 10

`ReflectionCoefficientAtSP` and `Sigma0` are globals appended to throughout a run,
but `HydroGNSS_extract.m` line 5 already runs `clear global` at function entry,
before the `global` declarations on lines 8–9. Both therefore start empty on
every call, including after a run that errored out. No change made.

Residual caveat: this only holds while `HydroGNSS_extract` is the entry point.
Calling `read_L1Bproduct` directly does not clear anything first.

---

### BUG 7 — `LatSouth` re-assigned instead of `Dayinit` — **FIXED**
**File:** `ReadConfFile.m` line 62

Inside the `Dayinit` block, line 62 read `LatSouth = double(LatSouth)` —
re-converting a value already converted at line 35, and doing nothing for
`Dayinit`. Removed.

Note it was *not* changed to `Dayinit = double(Dayinit)`: `Dayinit` holds a
timestamp string, so `double()` would yield character codes. It is consumed by
`datetime()` at `HydroGNSS_extract.m:142`, which wants the string.

---

### BUG 8 — inconsistent string comparison hid a silent config failure — **FIXED**
**File:** `HydroGNSS_extract.m` lines 220 and 708 (before the fix)

```matlab
if ProcessingSatellite=="Both" | ProcessingSatellite=="both"   % two cases spelled out
if DataFilter==string('Land')                                   % only one case
```

The `DataFilter` test matched `Land` only, and line 860 is a bare `else`. A config
with `DataFilter=land` or `LAND` therefore fell through to "keep everything" and
logged *"keeping all data over land and ocean"* — an unfiltered dataset with no
warning that the value was unrecognised.

Both now use `strcmpi`. **Behaviour change:** case variants of `Land` now actually
filter, so any earlier run that used a lowercase value and was accepted as
unfiltered will produce different output.

---

## MEMORY

### LEAK 1 — NetCDF handles leaked on any error — **FIXED**
**File:** `read_L1Bproduct.m` — opens ~line 108/173, closes ~line 1620

`ncid` (metadata) and `ncid2` (DDM) were opened and then closed ~1,480 lines
later, with nothing in between protected. There is no `continue` or `return` in
that span (the three in the function are all above the open), so the only way to
skip the close was an error — which is exactly what happened. The handle from the
failing block stayed open and the exception took the run down.

Fixed in three parts:
- the metadata open is now guarded, and a failure skips the block instead of the run;
- the whole block body runs inside `try`, with a `catch` that logs, closes both
  handles, and `continue`s to the next block;
- the close now tests `ncid2 >= 0` (an actual handle) rather than the
  `readDDMsinglefile` flag, which can disagree when the DDM open failed.

**Trade-off:** block failures are now warnings in the log rather than a hard stop,
so the log needs reading after a run.

---

### LEAK 2 — `time` appended twice per iteration — **SKIPPED**
**File:** `HydroGNSS_extract.m` lines 331–341

`t_track` is read and appended to `time` at lines 331/334, then read and appended
again at 340/341, so `time` ends up twice its correct length.

**Correction to the original entry:** this is *not* a data correctness bug.
`time` appears in only four places in the file (init, read, and the two appends);
it is never read back, never filtered by `LandSPindx`, and not in the `save` list
at line 873 — that saves `timeUTC`. The duplication costs memory only.

Worth recording, though: line 252 declares `time = single([])` while line 333
comments *"full precision"*. Datenums are ~739,650, where `single` spacing is
2²⁰⁻²⁴ = 0.0625 days ≈ **1.5 hours**. Anyone who adds `'time'` to the save list
trusting that comment gets uselessly quantised timestamps. `timeUTC` is unaffected
— line 344 builds it from `t_track` (still `double`).

Left unchanged by decision; the options were to delete `time` or to make it `double`.

---

### LEAK 3 — growing arrays cause O(N²) reallocation — **OPEN**
**File:** `HydroGNSS_extract.m` lines ~330–368

`numOfSP` is known before the loop (line 241), yet ~15 arrays start empty and grow
by concatenation: `timeUTC`, `dayOfYear`, `secondOfDay`, `Year`,
`specularPointLat`, `specularPointLon`, `Landtypesub`,
`ReceiverSubSatLatitude_all`, `ReceiverSubSatLongitude_all`, `ReceiverPositionX_all`,
`THETA`, `Onboardspeclat`, `Onboardspeclon`, `spAzimuthAngleDegOrbit`, `SixHourDir`.
Each `[arr; new]` copies the whole array. The `reflectivityLinear_*` / `SNR_*`
arrays are already preallocated and indexed with `intrack:fintrack`, so the pattern
to follow is in the same loop.

Not applied: it is the largest change on the list, and naive `NaN(numOfSP,1)`
preallocation would silently change the *class* of some outputs (e.g. `Landtypesub`
is currently whatever integer type `LandType` has, via concatenation with `[]`).
A type-preserving version — collect per-track into a cell, then one `vertcat` —
is the safer route.

---

### LEAK 4 / LEAK 5 — `Sigma0` holds every DDM for the whole run — **FIXED**
**File:** `HydroGNSS_extract.m`, after the assembly loop (line 663)

`Sigma0` accumulates raw `uint16` DDM arrays for every track across the entire run
and was never released, staying resident through the land filter and the `save` —
the peak-memory part of the run. Its last read is line 653, inside the assembly
loop. Now released immediately after that loop with `clear global Sigma0`
(a plain `clear` would only drop the local link and leave the data allocated).

**Correction to the original entry:** LEAK 4 proposed clearing
`ReflectionCoefficientAtSP` as well. That is not possible — line 2 declares it as
this function's return value, so clearing it would make `HydroGNSS_extract` return
nothing. Only `Sigma0` can be released here.

---

### LEAK 6 — stale group-id caches between blocks — **FIXED** (hygiene)
**File:** `read_L1Bproduct.m` (~line 102)

`coinNcids` / `coinNcids2` are rebuilt per 6-hour block but indexed by track
number, so a block with fewer tracks leaves higher-indexed entries from the
previous block pointing into a closed file. Now cleared at the top of each block.

**Honest scoping:** the loop bound is the current block's `Num_Groups`, so those
stale entries were never actually reached. This is defensive hygiene and a small
per-block memory release, not the fix of an active bug.

---

### LEAK 7 — receiver position arrays kept after use — **NOT A BUG**
**File:** `read_L1Bproduct.m` (~line 136)

`IntegrationMidPointTimetot`, `ReceiverPosition{X,Y,Z}tot` and
`ReceiverSubSat{Latitude,Longitude}tot` are function-local, overwritten every
block, and freed by MATLAB when the function returns. There is no accumulation
across blocks and no leak. No change made.
