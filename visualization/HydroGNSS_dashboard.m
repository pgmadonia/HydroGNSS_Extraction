function HydroGNSS_dashboard(matFile)
%HYDROGNSS_DASHBOARD  Interactive viewer for HydroGNSS extraction .mat outputs.
%
%   HydroGNSS_dashboard              Opens the app; use the "Load .mat" button.
%   HydroGNSS_dashboard(matFile)     Opens the app and loads matFile immediately.
%
%   The .mat files produced by HydroGNSS_extract.m store one column vector per
%   variable, with one row per specular point (all the same length as
%   specularPointLat). This tool auto-discovers those variables and lets you:
%
%     * Map      - specular points on a lat/lon map, coloured by any variable
%     * Histogram- distribution of any numeric variable
%     * Scatter  - any variable vs any other, coloured by a third
%     * TimeSeries- any numeric variable against timeUTC
%     * Statistics- summary table (count / min / max / mean / median / std / NaN%)
%
%   A filter panel restricts every plot to a subset of points (constellation,
%   land type, incidence angle, time window, and an optional "exclude flagged"
%   using any of the notToBeUsed_* flags). Filters apply live to all views.
%
%   No Mapping Toolbox required: if geoscatter/geoaxes are unavailable the Map
%   view falls back to a plain longitude/latitude scatter.
%
%   Example:
%       HydroGNSS_dashboard('D:\output\Sudd_25-08-26_10-30.mat')

%% ------------------------------------------------------------------ state
D = struct();          % holds all shared state (loaded data, handles, config)
D.S = struct();        % raw loaded struct
D.file = '';           % current file path
D.N = 0;               % number of specular points (reference length)
D.numVars = {};        % names of numeric per-point vectors (plottable)
D.catVars = {};        % names of categorical/string per-point vectors
D.flagVars = {};       % names of notToBeUsed_* flag vectors
D.latName = '';        % chosen latitude variable
D.lonName = '';        % chosen longitude variable
D.timeName = '';       % chosen datetime variable (if any)
D.hasMapping = ~isempty(which('geoscatter')) && ~isempty(which('geoaxes'));

%% ---------------------------------------------------------------- figure
fig = uifigure('Name','HydroGNSS Dashboard', ...
    'Position',[100 100 1220 720], ...
    'Color',[0.96 0.96 0.98]);

outer = uigridlayout(fig,[1 2]);
outer.ColumnWidth = {330,'1x'};
outer.Padding = [8 8 8 8];
outer.ColumnSpacing = 8;

% ---- left: controls (scrollable) ---------------------------------------
ctrlPanel = uipanel(outer,'Title','Controls','Scrollable','on');
ctrl = uigridlayout(ctrlPanel,[1 1]);
ctrl.RowHeight = repmat({'fit'},1,48);   % pre-sized; unused rows collapse to 0
ctrl.ColumnWidth = {'1x'};
ctrl.RowSpacing = 6;
ctrl.Padding = [8 8 8 8];

row = 0;
loadBtn = uibutton(ctrl,'Text','Load .mat ...','ButtonPushedFcn',@(~,~)onLoad());
loadBtn.Layout.Row = nextRow(); loadBtn.Layout.Column = 1;

fileLbl = uilabel(ctrl,'Text','(no file loaded)','FontAngle','italic', ...
    'WordWrap','on','FontColor',[0.35 0.35 0.4]);
fileLbl.Layout.Row = nextRow(); fileLbl.Layout.Column = 1;

addHeader('Plot');
plotDD = addDropdown('Plot type', ...
    {'Map','Histogram','Scatter','Time series','Statistics'});
plotDD.ValueChangedFcn = @(~,~)onPlotTypeChange();

xDD    = addDropdown('X variable',{''});
yDD    = addDropdown('Y variable',{''});
colorDD= addDropdown('Colour by',{''});
cmapDD = addDropdown('Colormap',{'parula','turbo','jet','hot','cool','viridis-ish (parula)','gray'});
cmapDD.Value = 'parula';

dbChk  = addCheckbox('dB scale (Y / value, 10*log10)',false);
dbXChk = addCheckbox('dB scale (X axis, scatter)',false);
nbinsSpin = addSpinner('Histogram bins',10,500,50);
sizeSpin  = addSpinner('Marker size',1,60,10);
maxSpin   = addSpinner('Max points drawn (x1000)',1,5000,200);

addHeader('Filters');
constLst = addListbox('Constellation',{});
ltMinField = addNumField('LandType min',[]);
ltMaxField = addNumField('LandType max',[]);
incMinField= addNumField('Incidence angle min (deg)',[]);
incMaxField= addNumField('Incidence angle max (deg)',[]);
t0Field = addTextField('Time from (yyyy-MM-dd HH:mm:ss)','');
t1Field = addTextField('Time to   (yyyy-MM-dd HH:mm:ss)','');
flagDD  = addDropdown('Exclude flagged using',{'(none)'});
flagChk = addCheckbox('Exclude flagged points',false);

applyBtn = uibutton(ctrl,'Text','Apply / Refresh','BackgroundColor',[0.20 0.45 0.85], ...
    'FontColor','w','FontWeight','bold','ButtonPushedFcn',@(~,~)refresh());
applyBtn.Layout.Row = nextRow(); applyBtn.Layout.Column = 1;

resetBtn = uibutton(ctrl,'Text','Reset filters','ButtonPushedFcn',@(~,~)resetFilters());
resetBtn.Layout.Row = nextRow(); resetBtn.Layout.Column = 1;

exportBtn = uibutton(ctrl,'Text','Export current view (PNG)','ButtonPushedFcn',@(~,~)onExport());
exportBtn.Layout.Row = nextRow(); exportBtn.Layout.Column = 1;

% ---- right: plot area + status -----------------------------------------
rightPanel = uipanel(outer);
right = uigridlayout(rightPanel,[2 1]);
right.RowHeight = {'1x','fit'};
right.Padding = [6 6 6 6];

plotHost = uipanel(right,'BorderType','none');
plotHost.Layout.Row = 1;
ax = [];   % current axes handle (created on demand)

statusLbl = uilabel(right,'Text','Load a HydroGNSS .mat output to begin.', ...
    'FontColor',[0.3 0.3 0.35]);
statusLbl.Layout.Row = 2;

% ---- optional immediate load -------------------------------------------
if nargin >= 1 && ~isempty(matFile)
    loadFile(matFile);
end

onPlotTypeChange();   % set initial enabled/disabled control states

%% ================================================================ nested
    function r = nextRow()
        row = row + 1; r = row;
    end

    function addHeader(txt)
        h = uilabel(ctrl,'Text',txt,'FontWeight','bold','FontSize',13, ...
            'FontColor',[0.15 0.25 0.45]);
        h.Layout.Row = nextRow(); h.Layout.Column = 1;
    end

    function dd = addDropdown(label,items)
        addSmallLabel(label);
        dd = uidropdown(ctrl,'Items',items);
        dd.Layout.Row = nextRow(); dd.Layout.Column = 1;
    end

    function c = addCheckbox(label,val)
        c = uicheckbox(ctrl,'Text',label,'Value',val);
        c.Layout.Row = nextRow(); c.Layout.Column = 1;
    end

    function s = addSpinner(label,lo,hi,val)
        addSmallLabel(label);
        s = uispinner(ctrl,'Limits',[lo hi],'Value',val,'Step',1,'RoundFractionalValues','on');
        s.Layout.Row = nextRow(); s.Layout.Column = 1;
    end

    function f = addNumField(label,~)
        % Empty numeric field means "no bound". AllowEmpty exists only on
        % newer MATLAB; fall back to a NaN sentinel, which the mask treats
        % as "no bound" as well.
        addSmallLabel(label);
        try
            f = uieditfield(ctrl,'numeric','AllowEmpty','on','Value',[], ...
                'Placeholder','none');
        catch
            f = uieditfield(ctrl,'numeric','Value',NaN);
        end
        f.Layout.Row = nextRow(); f.Layout.Column = 1;
    end

    function f = addTextField(label,val)
        addSmallLabel(label);
        f = uieditfield(ctrl,'text','Value',val);
        f.Layout.Row = nextRow(); f.Layout.Column = 1;
    end

    function lb = addListbox(label,items)
        addSmallLabel(label);
        lb = uilistbox(ctrl,'Items',items,'Multiselect','on');
        lb.Layout.Row = nextRow(); lb.Layout.Column = 1;
    end

    function addSmallLabel(txt)
        h = uilabel(ctrl,'Text',txt,'FontSize',11,'FontColor',[0.35 0.35 0.4]);
        h.Layout.Row = nextRow(); h.Layout.Column = 1;
    end

    % --------------------------------------------------------------- load
    function onLoad()
        [f,p] = uigetfile({'*.mat','MATLAB data (*.mat)'},'Select a HydroGNSS output .mat');
        figure(fig);                       % keep app in front after dialog
        if isequal(f,0), return; end
        loadFile(fullfile(p,f));
    end

    function loadFile(fpath)
        setStatus(['Loading ' fpath ' ...']);
        drawnow;
        try
            S = load(fpath);
        catch err
            uialert(fig,['Could not load file:' newline err.message],'Load error');
            setStatus('Load failed.');
            return;
        end
        D.S = S;
        D.file = fpath;

        % Reference length: prefer specularPointLat, else the most common
        % vector length among the fields.
        if isfield(S,'specularPointLat')
            D.N = numel(S.specularPointLat);
        else
            D.N = mostCommonLength(S);
        end

        classifyFields();
        if isempty(D.latName) || isempty(D.lonName)
            uialert(fig,['No latitude/longitude variables found. ' ...
                'Expected specularPointLat / specularPointLon.'],'Missing coordinates');
        end
        populateControls();
        [~,nm,ext] = fileparts(fpath);
        fileLbl.Text = [nm ext];
        fileLbl.FontAngle = 'normal';
        refresh();
    end

    function classifyFields()
        S = D.S; N = D.N;
        names = fieldnames(S);
        num = {}; catNames = {}; flags = {};
        latName = ''; lonName = ''; timeName = '';
        for i = 1:numel(names)
            nm = names{i};
            v = S.(nm);
            if ~isvector(v) || numel(v) ~= N
                continue;   % not a per-point vector
            end
            if isdatetime(v)
                if isempty(timeName), timeName = nm; end
                continue;
            end
            if isnumeric(v) || islogical(v)
                if isLat(nm) && isempty(latName)
                    latName = nm;
                elseif isLon(nm) && isempty(lonName)
                    lonName = nm;
                end
                num{end+1} = nm; %#ok<AGROW>
                if startsWith(nm,'notToBeUsed')
                    flags{end+1} = nm; %#ok<AGROW>
                end
            elseif isstring(v) || iscellstr(v) || ischar(v) || iscategorical(v)
                catNames{end+1} = nm; %#ok<AGROW>
            end
        end
        % Prefer the canonical specular point coordinates if present.
        if isfield(S,'specularPointLat'), latName = 'specularPointLat'; end
        if isfield(S,'specularPointLon'), lonName = 'specularPointLon'; end

        D.numVars = sort(num);
        D.catVars = sort(catNames);
        D.flagVars = sort(flags);
        D.latName = latName;
        D.lonName = lonName;
        D.timeName = timeName;
    end

    function populateControls()
        numItems = D.numVars;
        if isempty(numItems), numItems = {''}; end

        xDD.Items = numItems;
        yDD.Items = numItems;
        colorItems = [{'(uniform)'} numItems];
        colorDD.Items = colorItems;

        % Sensible defaults
        colorDD.Value = firstMatch(numItems, ...
            {'reflectivityLinear_1_L','reflectivityLinear_5_L','SNR_1_L'}, colorDD.Items{1});
        xDD.Value = firstMatch(numItems,{'incidenceAngleDeg'},numItems{1});
        yDD.Value = firstMatch(numItems, ...
            {'reflectivityLinear_1_L','reflectivityLinear_5_L'},numItems{min(2,end)});

        % Constellation filter
        if any(strcmp(D.catVars,'constellation'))
            u = uniqueLabels(D.S.constellation);
            constLst.Items = u;
            constLst.Value = u;   % all selected by default
        else
            constLst.Items = {};
        end

        % Flag dropdown
        if isempty(D.flagVars)
            flagDD.Items = {'(none)'};
        else
            flagDD.Items = D.flagVars;
            flagDD.Value = D.flagVars{1};
        end

        setStatus(sprintf('Loaded %d points | %d numeric, %d categorical variables%s', ...
            D.N, numel(D.numVars), numel(D.catVars), ...
            iff(D.hasMapping,'',' | Mapping Toolbox absent: map uses plain scatter')));
    end

    % ------------------------------------------------------------- filters
    function mask = currentMask()
        S = D.S; N = D.N;
        mask = true(N,1);

        % Constellation
        if ~isempty(constLst.Items) && ~isempty(constLst.Value)
            sel = string(constLst.Value);
            if numel(sel) < numel(constLst.Items)
                cvals = string(S.constellation(:));
                mask = mask & ismember(cvals, sel);
            end
        end

        % Land type range
        if isfield(S,'Landtypesub')
            lt = double(S.Landtypesub(:));
            lo = boundVal(ltMinField.Value); hi = boundVal(ltMaxField.Value);
            if ~isnan(lo), mask = mask & (lt >= lo); end
            if ~isnan(hi), mask = mask & (lt <= hi); end
        end

        % Incidence angle range
        if isfield(S,'incidenceAngleDeg')
            ia = double(S.incidenceAngleDeg(:));
            lo = boundVal(incMinField.Value); hi = boundVal(incMaxField.Value);
            if ~isnan(lo), mask = mask & (ia >= lo); end
            if ~isnan(hi), mask = mask & (ia <= hi); end
        end

        % Time window
        if ~isempty(D.timeName)
            t = D.S.(D.timeName)(:);
            mask = mask & applyTimeBound(t, t0Field.Value, @ge);
            mask = mask & applyTimeBound(t, t1Field.Value, @le);
        end

        % Exclude flagged
        if flagChk.Value && ~strcmp(flagDD.Value,'(none)') && isfield(S,flagDD.Value)
            fl = S.(flagDD.Value)(:);
            mask = mask & ~(double(fl) == 1);
        end
    end

    function m = applyTimeBound(t, str, cmp)
        m = true(numel(t),1);
        str = strtrim(str);
        if isempty(str), return; end
        try
            bnd = datetime(str);
        catch
            return;   % ignore unparseable bound
        end
        m = cmp(t(:), bnd);
        m(isnat(t(:))) = false;
    end

    function resetFilters()
        if ~isempty(constLst.Items), constLst.Value = constLst.Items; end
        clearNum(ltMinField); clearNum(ltMaxField);
        clearNum(incMinField); clearNum(incMaxField);
        t0Field.Value = ''; t1Field.Value = '';
        flagChk.Value = false;
        refresh();
    end

    function clearNum(f)
        % Reset a numeric filter field regardless of AllowEmpty support.
        try, f.Value = []; catch, f.Value = NaN; end
    end

    % ------------------------------------------------------------- drawing
    function onPlotTypeChange()
        pt = plotDD.Value;
        setEnable(xDD, any(strcmp(pt,{'Scatter'})));
        setEnable(yDD, any(strcmp(pt,{'Scatter','Time series','Histogram'})));
        setEnable(colorDD, any(strcmp(pt,{'Map','Scatter'})));
        setEnable(nbinsSpin, strcmp(pt,'Histogram'));
        setEnable(cmapDD, any(strcmp(pt,{'Map','Scatter'})));
        setEnable(dbChk, any(strcmp(pt,{'Map','Scatter','Histogram','Time series'})));
        setEnable(dbXChk, strcmp(pt,'Scatter'));
        if ~isempty(D.file), refresh(); end
    end

    function refresh()
        if isempty(D.file)
            setStatus('Load a HydroGNSS .mat output to begin.');
            return;
        end
        mask = currentMask();
        nSel = nnz(mask);
        if nSel == 0
            resetAxesTo2D();
            title(ax,'No points match the current filters');
            setStatus('0 points after filtering. Loosen the filters.');
            return;
        end

        switch plotDD.Value
            case 'Map',        drawMap(mask);
            case 'Histogram',  drawHistogram(mask);
            case 'Scatter',    drawScatter(mask);
            case 'Time series',drawTimeSeries(mask);
            case 'Statistics', drawStats(mask);
        end
        setStatus(sprintf('%d of %d points shown (%.1f%%)', ...
            nSel, D.N, 100*nSel/max(D.N,1)));
    end

    function [idx, note] = drawIndex(mask)
        % Subsample for display if there are more selected points than the cap.
        idx = find(mask);
        cap = maxSpin.Value * 1000;
        note = '';
        if numel(idx) > cap
            sel = randperm(numel(idx), cap);
            idx = sort(idx(sel));
            note = sprintf(' (subsampled to %d)', cap);
        end
    end

    function drawMap(mask)
        if isempty(D.latName) || isempty(D.lonName)
            resetAxesTo2D();
            title(ax,'No latitude/longitude variables available');
            return;
        end
        [idx,note] = drawIndex(mask);
        lat = double(D.S.(D.latName)(idx));
        lon = double(D.S.(D.lonName)(idx));
        [c,cLabel] = colorData(idx);

        if D.hasMapping
            resetAxesToGeo();
            if isempty(c)
                geoscatter(ax, lat, lon, sizeSpin.Value, 'filled');
            else
                geoscatter(ax, lat, lon, sizeSpin.Value, c, 'filled');
                applyColorbar(cLabel);
            end
            try, geobasemap(ax,'grayland'); catch, end
        else
            resetAxesTo2D();
            if isempty(c)
                scatter(ax, lon, lat, sizeSpin.Value, 'filled');
            else
                scatter(ax, lon, lat, sizeSpin.Value, c, 'filled');
                applyColorbar(cLabel);
            end
            xlabel(ax,'Longitude'); ylabel(ax,'Latitude');
            axis(ax,'equal'); grid(ax,'on');
        end
        title(ax,['Specular points' note],'Interpreter','none');
    end

    function drawHistogram(mask)
        resetAxesTo2D();
        name = yDD.Value;
        v = getNumeric(name, mask);
        v = v(isfinite(v));
        if dbChk.Value, v = v(v>0); v = 10*log10(v); name = [name ' [dB]']; end
        if isempty(v)
            title(ax,'No finite data to histogram'); return;
        end
        histogram(ax, v, nbinsSpin.Value, 'FaceColor',[0.20 0.45 0.85]);
        xlabel(ax,name,'Interpreter','none'); ylabel(ax,'Count');
        grid(ax,'on');
        title(ax,sprintf('%s  (n=%d, \\mu=%.4g, \\sigma=%.4g)', ...
            name, numel(v), mean(v), std(v)),'Interpreter','tex');
    end

    function drawScatter(mask)
        resetAxesTo2D();
        [idx,note] = drawIndex(mask);
        x = getNumericIdx(xDD.Value, idx);
        y = getNumericIdx(yDD.Value, idx);
        [c,cLabel] = colorData(idx);
        % dB per axis, independently. log10 needs positive input, so drop any
        % non-positive points on an axis being converted (both axes if both on).
        good = true(size(x));
        if dbXChk.Value, good = good & (x>0); end
        if dbChk.Value,  good = good & (y>0); end
        if dbXChk.Value || dbChk.Value
            x = x(good); y = y(good);
            if ~isempty(c), c = c(good); end
        end
        if dbXChk.Value, x = 10*log10(x); end
        if dbChk.Value,  y = 10*log10(y); end
        if isempty(c)
            scatter(ax, x, y, sizeSpin.Value, 'filled','MarkerFaceAlpha',0.5);
        else
            scatter(ax, x, y, sizeSpin.Value, c, 'filled','MarkerFaceAlpha',0.6);
            applyColorbar(cLabel);
        end
        xl = xDD.Value; if dbXChk.Value, xl = [xl ' [dB]']; end
        xlabel(ax,xl,'Interpreter','none');
        yl = yDD.Value; if dbChk.Value, yl = [yl ' [dB]']; end
        ylabel(ax,yl,'Interpreter','none');
        grid(ax,'on');
        title(ax,[xDD.Value ' vs ' yDD.Value note],'Interpreter','none');
    end

    function drawTimeSeries(mask)
        resetAxesTo2D();
        if isempty(D.timeName)
            title(ax,'No datetime variable (timeUTC) available'); return;
        end
        [idx,note] = drawIndex(mask);
        t = D.S.(D.timeName)(idx);
        y = getNumericIdx(yDD.Value, idx);
        name = yDD.Value;
        if dbChk.Value, good = y>0; t=t(good); y=10*log10(y(good)); name=[name ' [dB]']; end
        [t,order] = sort(t); y = y(order);
        plot(ax, t, y, '.','MarkerSize',max(4,sizeSpin.Value),'Color',[0.20 0.45 0.85]);
        xlabel(ax,D.timeName,'Interpreter','none');
        ylabel(ax,name,'Interpreter','none');
        grid(ax,'on');
        title(ax,[name ' over time' note],'Interpreter','none');
    end

    function drawStats(mask)
        % Build a summary table over the current selection and show it.
        idx = find(mask);
        vars = D.numVars;
        n = numel(vars);
        Count=zeros(n,1); Min=nan(n,1); Max=nan(n,1); Mean=nan(n,1);
        Median=nan(n,1); Std=nan(n,1); NaNpct=nan(n,1);
        for i=1:n
            v = double(D.S.(vars{i})(idx));
            fin = isfinite(v);
            Count(i)=nnz(fin);
            NaNpct(i)=100*(numel(v)-nnz(fin))/max(numel(v),1);
            if any(fin)
                vf=v(fin);
                Min(i)=min(vf); Max(i)=max(vf); Mean(i)=mean(vf);
                Median(i)=median(vf); Std(i)=std(vf);
            end
        end
        T = table(Count,Min,Max,Mean,Median,Std,NaNpct, ...
            'RowNames',vars, ...
            'VariableNames',{'Count','Min','Max','Mean','Median','Std','NaN_pct'});

        delete(allchild(plotHost)); ax = [];
        g = uigridlayout(plotHost,[1 1]); g.Padding=[0 0 0 0];
        ut = uitable(g,'Data',T,'RowName',T.Properties.RowNames);
        ut.Layout.Row=1; ut.Layout.Column=1;
    end

    % -------------------------------------------------------- data helpers
    function v = getNumeric(name, mask)
        v = double(D.S.(name)(:));
        v = v(mask);
    end
    function v = getNumericIdx(name, idx)
        v = double(D.S.(name)(idx));
        v = v(:);
    end

    function [c,label] = colorData(idx)
        c = []; label = '';
        if ~any(strcmp(plotDD.Value,{'Map','Scatter'})), return; end
        cv = colorDD.Value;
        if isempty(cv) || strcmp(cv,'(uniform)'), return; end
        c = double(D.S.(cv)(idx)); c = c(:);
        label = cv;
        if dbChk.Value && strcmp(plotDD.Value,'Map')
            good = c>0; c(~good)=NaN; c=10*log10(c); label=[cv ' [dB]'];
        end
    end

    function applyColorbar(label)
        applyColormap();
        cb = colorbar(ax);
        cb.Label.String = label;
        cb.Label.Interpreter = 'none';
    end

    function applyColormap()
        name = cmapDD.Value;
        switch name
            case 'viridis-ish (parula)', name = 'parula';
        end
        try, colormap(ax, name); catch, colormap(ax,'parula'); end
    end

    % ------------------------------------------------------- axes lifecycle
    function resetAxesTo2D()
        delete(allchild(plotHost));
        ax = uiaxes(plotHost);
        ax.Units = 'normalized'; ax.Position = [0.10 0.12 0.86 0.82];
    end
    function resetAxesToGeo()
        delete(allchild(plotHost));
        ax = geoaxes(plotHost);
        ax.Units = 'normalized'; ax.Position = [0.06 0.08 0.90 0.88];
    end

    % --------------------------------------------------------------- export
    function onExport()
        if isempty(ax) || ~isvalid(ax)
            uialert(fig,'Nothing to export yet.','Export'); return;
        end
        [f,p] = uiputfile({'*.png','PNG image';'*.pdf','PDF'},'Save current view');
        figure(fig);
        if isequal(f,0), return; end
        try
            exportgraphics(ax, fullfile(p,f), 'Resolution',200);
            setStatus(['Saved ' fullfile(p,f)]);
        catch err
            uialert(fig,err.message,'Export failed');
        end
    end

    % --------------------------------------------------------------- utils
    function setStatus(txt), statusLbl.Text = txt; end
end

%% ==================================================== file-scope helpers
function setEnable(h,tf)
    if tf, h.Enable='on'; else, h.Enable='off'; end
end

function b = boundVal(v)
    % Normalise a numeric-field value to NaN when it represents "no bound".
    if isempty(v), b = NaN; else, b = double(v); end
end

function tf = isLat(nm)
    tf = ~isempty(regexpi(nm,'lat','once'));
end
function tf = isLon(nm)
    tf = ~isempty(regexpi(nm,'lon','once'));
end

function L = mostCommonLength(S)
    names = fieldnames(S); lens = [];
    for i=1:numel(names)
        v = S.(names{i});
        if isvector(v), lens(end+1) = numel(v); end %#ok<AGROW>
    end
    if isempty(lens), L = 0; else, L = mode(lens); end
end

function u = uniqueLabels(v)
    u = unique(string(v(:)),'stable');
    u = cellstr(u(:).');
end

function out = firstMatch(items, prefs, fallback)
    out = fallback;
    for i=1:numel(prefs)
        if any(strcmp(items,prefs{i})), out = prefs{i}; return; end
    end
    if ~isempty(items) && isempty(out), out = items{1}; end
end

function out = iff(cond,a,b)
    if cond, out=a; else, out=b; end
end
