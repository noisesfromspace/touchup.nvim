local M = {}

local api = vim.api

-- Underline-style attributes. The grid draws only one underline style per
-- cell, so a merged group carries exactly the diagnostic's style.
local UL_ATTRS = { "underline", "undercurl", "underdouble", "underdotted", "underdashed" }

local SEVERITY_NAMES = {
	[vim.diagnostic.severity.ERROR] = "Error",
	[vim.diagnostic.severity.WARN] = "Warn",
	[vim.diagnostic.severity.INFO] = "Info",
	[vim.diagnostic.severity.HINT] = "Hint",
}

-- Cached merged group names, keyed by `base|severity`.
local merged = {}

---Columns a diagnostic covers on `row`, or nil when it does not reach the row.
---Multiline diagnostics cover to end of line on the start row, the full line
---in between, and up to end_col on the end row (extmark range semantics).
---Exposed for testing.
---@param d table diagnostic item (0.10+ `range` form or legacy lnum/col form)
---@param row integer 0-based
---@return integer? c0, integer? c1
function M._row_bounds(d, row)
	local sr, sc, er, ec
	if d.range then
		sr, sc = d.range.start[1], d.range.start[2]
		er, ec = d.range["end"][1], d.range["end"][2]
	else
		sr, sc, er, ec = d.lnum, d.col, d.end_lnum, d.end_col
	end
	if row < sr or row > er then
		return nil
	end
	if sr == er then
		return sc, ec
	end
	if row == sr then
		return sc, math.huge
	end
	if row == er then
		return 0, ec
	end
	return 0, math.huge
end

---Most severe diagnostic severity whose underline covers any cell in
---[c0, c1) on `row`, or nil.
---@param bufnr integer
---@param row integer 0-based
---@param c0 integer 0-based
---@param c1 integer 0-based, exclusive
---@return integer? severity
local function severity_for(bufnr, row, c0, c1)
	local best
	for _, d in ipairs(vim.diagnostic.get(bufnr, { lnum = row })) do
		local sev = d.severity
		if type(sev) == "number" and SEVERITY_NAMES[sev] then
			local d0, d1 = M._row_bounds(d, row)
			if d0 and d1 and d0 < c1 and d1 > c0 then
				if not best or sev < best then
					best = sev
				end
			end
		end
	end
	return best
end

---Create (once) and cache a group holding `base`'s colors plus the diagnostic
---underline style for `severity`, resolved from DiagnosticUnderline<Severity>.
---@param base string
---@param severity integer
---@return string
local function merged_group(base, severity)
	local key = base .. "|" .. severity
	local name = merged[key]
	if name then
		return name
	end

	local sev_name = SEVERITY_NAMES[severity]
	-- nvim_get_hl resolves global groups only for the current buffer (bufnr 0);
	-- touchup and DiagnosticUnderline* groups are global.
	local attrs = api.nvim_get_hl(0, { name = base, link = false })
	local uattrs = api.nvim_get_hl(0, { name = "DiagnosticUnderline" .. sev_name, link = false })

	-- Nothing to merge when the underline group carries no underline style.
	local styled = false
	for _, a in ipairs(UL_ATTRS) do
		if uattrs[a] or (uattrs.cterm and uattrs.cterm[a]) then
			styled = true
			break
		end
	end
	if not styled then
		return base
	end

	name = "TouchupDiag" .. sev_name .. base

	-- The diagnostic's underline style replaces any from the base group
	-- (only one style renders per cell).
	for _, a in ipairs(UL_ATTRS) do
		attrs[a] = false
	end
	local cterm = attrs.cterm
	if cterm then
		for _, a in ipairs(UL_ATTRS) do
			cterm[a] = nil
		end
	end
	for _, a in ipairs(UL_ATTRS) do
		if uattrs[a] then
			attrs[a] = true
		end
		if uattrs.cterm and uattrs.cterm[a] then
			cterm = cterm or {}
			cterm[a] = true
		end
	end
	if cterm then
		attrs.cterm = cterm
	end
	attrs.sp = uattrs.sp
	attrs.default = true

	api.nvim_set_hl(0, name, attrs)
	merged[key] = name
	return name
end

---Overlay highlight group for a cell (or cell range) starting at (row, c0):
---`base` unchanged, or a group combining `base`'s colors with the
---diagnostic's underline style when a diagnostic underline covers the cell.
---@param bufnr integer
---@param row integer 0-based
---@param c0 integer 0-based start column
---@param base string
---@param c1 integer? 0-based end column (exclusive); defaults to c0 + 1
---@return string
function M.overlay(bufnr, row, c0, base, c1)
	local sev = severity_for(bufnr, row, c0, c1 or c0 + 1)
	if not sev then
		return base
	end
	return merged_group(base, sev)
end

---Forget cached merged groups and unlink them so the next redraw rebuilds
---them with the current colorscheme's colors.
function M.clear()
	for _, name in pairs(merged) do
		api.nvim_set_hl(0, name, {})
	end
	merged = {}
end

return M
