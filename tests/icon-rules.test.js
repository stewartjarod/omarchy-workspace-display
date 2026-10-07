const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const source = fs.readFileSync(path.join(__dirname, '..', 'IconRules.js'), 'utf8')
  .replace(/^\.pragma library\s*$/m, '')
const rules = {}
vm.runInNewContext(source, rules, { filename: 'IconRules.js' })

test('uses initial title for a custom-class Kitty auto-launch window', () => {
  const kitty = rules.resolve('kitty', '', '', '')
  assert.equal(rules.resolve('agentic', 'brainfuck: workspace plugin', 'agentic', 'kitty'), kitty)
})

test('keeps an app-specific live title ahead of the terminal initial title', () => {
  const yazi = rules.resolve('yazi', '', '', '')
  assert.equal(rules.resolve('custom-terminal', 'Yazi: nica', 'custom-terminal', 'kitty'), yazi)
})

test('keeps the generic fallback when no window identity matches', () => {
  assert.equal(rules.resolve('unknown-class', 'unknown-title', '', ''), rules.fallback)
})

test('finds the app behind a Chrome web-app window class', () => {
  assert.equal(rules.appFor('chrome-mail.google.com__mail_u_0_-default').key, 'gmail')
  assert.equal(rules.appFor('chrome-calendar.google.com__calendar_u_0_r-default').key, 'calendar')
  assert.equal(rules.appFor('chrome-x.com__-default').key, 'x')
  assert.equal(rules.appFor('Spotify').key, 'spotify')
})

test('leaves ordinary browser windows without an app', () => {
  assert.equal(rules.appFor('chrome-youtube.com__-default'), null)
  assert.equal(rules.appFor('firefox'), null)
})

test('a workspace icon is saved per workspace, and only for known apps', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'Workspaces.qml'), 'utf8')
  assert.match(source, /item\.icon = root\.cleanIcon\(item\.icon\)/)
  assert.match(source, /function cleanIcon\(value\) \{\n\s*var app = IconRules\.appByKey\(value\)/)
  assert.doesNotMatch(source, /appIcon/)
})

test('editor offers Windows or Custom, with the icon picker enabled only for Custom', () => {
  const row = fs.readFileSync(path.join(__dirname, '..', 'WorkspaceRow.qml'), 'utf8')
  assert.match(row, /text: "WORKSPACE ICON"/)
  assert.match(row, /enabled: iconModeRow\.custom/)
  assert.match(row, /onChanged: function\(key\) \{ root\.host\.setIcon\(root\.targetKey, key\) \}/)
})

test('appByKey finds an app by its saved key', () => {
  assert.equal(rules.appByKey('calendar').label, 'Google Calendar')
  assert.equal(rules.appByKey('nope'), null)
})

test('Signal can be a workspace icon', () => {
  assert.equal(rules.appFor('signal').key, 'signal')
  assert.equal(rules.appByKey('signal').label, 'Signal')
})

test('Work and Play are workspace icons only, never matched to a window', () => {
  for (const key of ['work', 'play']) {
    assert.ok(rules.appByKey(key).glyph)
    assert.equal(rules.appFor(key), null)
  }
})

test('the Wraps web app window maps to the Wraps icon', () => {
  assert.equal(rules.appFor('chrome-app.wraps.dev__-default').key, 'wraps')
  assert.equal(rules.appFor('chrome-wraps.dev__-default').key, 'wraps')
})
