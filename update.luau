--!strict

local json = require("@std/json")
local net = require("@std/net")
local process = require("@std/process")
local stringext = require("@std/stringext")
local fs = require("@std/fs")

local GITHUB_API_URL = "https://api.github.com"
local PKG_NAME = "lute"
local PKG_FILE = "lute.nix"

local github_token: string? = process.env.GH_TOKEN
local pkg_file_contents = fs.readfiletostring(PKG_FILE)

local function string_escape_pattern(s: string)
	return (string.gsub(s, "[%%%.%(%)%*%+%?%-%^%$]", "%%%0"))
end

local function string_replace(s: string, replace: string, replacement: string)
	print(`{replace} -> {replacement}`)
	return (string.gsub(s, string_escape_pattern(replace), (string.gsub(replacement, "%%", "%%"))))
end

local function command_output(args: { string }): string
	local result = process.run(args)
	if not result.ok then
		print("-- stdout --")
		print(result.stdout)
		print("-- stderr --")
		print(result.stderr)
		error(`process failed with code {result.exitcode}`)
	end
	return result.stdout
end

if github_token == nil then
	local ok, result = pcall(command_output, { "gh", "auth", "token" })
	if ok then
		github_token = stringext.trim(result)
	end
end

local github_request_headers = {
	Accept = "application/json",
	Authorization = github_token and `Bearer {github_token}`,
	["User-Agent"] = "lute-nix",
	["X-GitHub-Api-Version"] = "2026-03-10",
}

local current_pkg = json.deserialize(command_output({
	"nix",
	"eval",
	"--raw",
	"--apply",
	[[
        pkg: builtins.toJSON {
		    inherit (pkg) version;
		    src = { inherit (pkg.src) owner repo outputHash; };
		    tune = { inherit (pkg.tune) outputHash; };
		}
    ]],
	`.#{PKG_NAME}`,
})) :: any

local repo = `{current_pkg.src.owner}/{current_pkg.src.repo}`
local current_version: string = current_pkg.version
local current_src_hash: string = current_pkg.src.outputHash

print(`repo: {repo}`)
print(`current version: {current_pkg.version}`)

local function fetch_latest_version()
	local response = net.request(`{GITHUB_API_URL}/repos/{repo}/releases`, {
		headers = github_request_headers,
	})
	if not response.ok then
		error(`response failed with {response.status}`)
	end
	local data = json.deserialize(response.body) :: any
	return data[1].tag_name
end

local latest_version = fetch_latest_version()
print(`latest version: {latest_version}`)

if current_version == latest_version then
	print("nothing to do")
	return
end

print("fetching new source...")

local new_src_hash: string = (json.deserialize(command_output({
	"nix-prefetch-git",
	"--url",
	`https://github.com/{repo}`,
	"--rev",
	latest_version,
	"--name",
	"source",
})) :: any).hash

print("determining new tune hash...")

local tune_drv = command_output({
	"nix",
	"eval",
	"--raw",
	"--apply",
	[[
        pkg: ((pkg.overrideAttrs (prevAttrs: {
    ]] .. `version = "{latest_version}"; src = prevAttrs.src.override \{ hash = "{new_src_hash}"; };` .. [[
        })).tune.overrideAttrs {
            outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        }).drvPath
    ]],
	`.#{PKG_NAME}`,
})

local tune_result = process.run({
	"nix",
	"build",
	`{tune_drv}^out`,
})
assert(not tune_result.ok, "building tune with fake hash should fail")

local tune_hash = string.match(
	tune_result.stderr,
	"specified:%s+sha256%-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=%s+got:%s+([^%s]+)"
)
assert(tune_hash ~= nil, "could not extract hash of tune derivation")

local new_pkg_file_contents = pkg_file_contents
new_pkg_file_contents = string_replace(new_pkg_file_contents, current_version, latest_version)
new_pkg_file_contents = string_replace(new_pkg_file_contents, current_src_hash, new_src_hash)
new_pkg_file_contents = string_replace(new_pkg_file_contents, current_pkg.tune.outputHash, tune_hash)

fs.writestringtofile(PKG_FILE, new_pkg_file_contents)
