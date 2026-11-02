// Ported from GitHub Desktop (MIT): app/src/lib/git/git-delimiter-parser.ts
import { expect, it } from 'vitest'
import { createLogParser } from '../../../src/main/git/git-delimiter-parser'

it('parses multiline, empty and control-character fields in both text and Buffer output', () => {
  const parser = createLogParser({ sha: '%H', body: '%b', parents: '%P' })
  expect(parser.formatArgs).toEqual(['-z', '--format=%H%x00%b%x00%P'])
  const value = 'first\0line\n\x1e\x1f한글\0\0second\0\0first\0'
  expect(parser.parse(value)).toEqual([
    { sha: 'first', body: 'line\n\x1e\x1f한글', parents: '' },
    { sha: 'second', body: '', parents: 'first' },
  ])
  expect(
    parser
      .parse(Buffer.from(value))
      .map((entry) => Object.fromEntries(Object.entries(entry).map(([k, v]) => [k, v.toString()])))
  ).toEqual(parser.parse(value))
  expect(parser.parse('')).toEqual([])
  expect(parser.parse('incomplete\0')).toEqual([])
})
