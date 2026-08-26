# HydroGNSS Dashboard

Interactive MATLAB app for visualizing the `.mat` files produced by the
extraction pipeline (`src/HydroGNSS_extract.m`).

Those outputs store **one column vector per variable**, with one row per
specular point (all the same length as `specularPointLat`). The dashboard
auto-discovers those vectors, so it keeps working even as new variables are
added to the `save(...)` call in `HydroGNSS_extract.m` — nothing here needs to
be edited when the output schema changes.

## Requirements

- MATLAB R2020b or newer (uses `uifigure` / `uigridlayout` app components).
- **Mapping Toolbox is optional.** If `geoscatter`/`geoaxes` are available the
  Map view uses a real basemap; otherwise it falls back to a plain
  longitude/latitude scatter — everything else is unchanged.

## Usage

From the MATLAB command window, with this folder on the path:

```matlab
addpath('visualization');       % once per session (or add to the project path)

HydroGNSS_dashboard             % opens the app, then use "Load .mat ..."
HydroGNSS_dashboard('D:\output\Sudd_25-08-26_10-30.mat')   % load immediately
```

## Views

| View          | What it shows                                                            |
|---------------|--------------------------------------------------------------------------|
| **Map**       | Specular points on a lat/lon map, coloured by any variable.              |
| **Histogram** | Distribution of any numeric variable (optional log axis).                |
| **Scatter**   | Any variable vs any other, coloured by a third.                          |
| **Time series** | Any numeric variable against `timeUTC`.                                |
| **Statistics** | Summary table (count, min, max, mean, median, std, % NaN) per variable. |

## Filters

All filters apply live to every view (press **Apply / Refresh** after changing
them):

- **Constellation** — multi-select (`GPS`, `Galileo`, …), read from the
  `constellation` field.
- **Land type** — min/max on `Landtypesub` (e.g. `< 210` keeps land only;
  Water = 210, Snow/ice = 220).
- **Incidence angle** — min/max on `incidenceAngleDeg`.
- **Time window** — from/to on `timeUTC` (`yyyy-MM-dd HH:mm:ss`).
- **Exclude flagged** — drops points where a chosen `notToBeUsed_*` flag == 1.

Leave a numeric or time field blank to disable that bound.

## Performance

Very large outputs are randomly subsampled for display (default cap: 200 000
points, adjustable via **Max points drawn**). Filtering and statistics always
run on the full selection; only the on-screen markers are subsampled.

## Export

**Export current view (PNG)** saves the active plot (PNG or PDF) at 200 dpi.
