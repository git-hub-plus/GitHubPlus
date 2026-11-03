import { describe, expect, it } from 'vitest'
import { isPrivateAddress, isValidRepositoryName } from '../../../../src/main/hub/shared/validation'

describe('hub LAN policy', () => {
  it('handles expanded mapped IPv6 and names beginning with allowed punctuation', () => {
    expect(isPrivateAddress('0:0:0:0:0:ffff:c0a8:101')).toBe(true)
    expect(isPrivateAddress('0:0:0:0:0:ffff:808:808')).toBe(false)
    for (const name of ['_repo', '-repo', '.repo']) expect(isValidRepositoryName(name)).toBe(true)
  })
  it.each([
    '10.0.0.1',
    '10.255.255.255',
    '172.16.0.1',
    '172.31.255.255',
    '192.168.0.1',
    '169.254.1.2',
    '127.0.0.1',
    '127.255.1.1',
    '::1',
    '0:0:0:0:0:0:0:1',
    'fc00::1',
    'fdff::1',
    'fe80::1%eth0',
    'febf::1',
    '::ffff:192.168.1.1',
    '::ffff:c0a8:101',
  ])('allows %s', (address) => expect(isPrivateAddress(address)).toBe(true))
  it.each([
    '8.8.8.8',
    '172.15.1.1',
    '172.32.0.1',
    '192.169.0.1',
    '169.253.1.1',
    '0.0.0.0',
    '100.64.0.1',
    '::',
    'fec0::1',
    '2001:db8::1',
    '::ffff:8.8.8.8',
    'localhost',
    '10.999.0.1',
    '',
  ])('rejects %s', (address) => expect(isPrivateAddress(address)).toBe(false))
  it.each(['repo', 'team-api', 'a_b.c', '123'])('accepts name %s', (name) =>
    expect(isValidRepositoryName(name)).toBe(true)
  )
  it.each(['..', 'a..b', '../a', 'a/b', 'a\\b', '', 'a b', '한글', 'CON', 'NUL.txt', 'a.', 'a\0b'])(
    'rejects name %s',
    (name) => expect(isValidRepositoryName(name)).toBe(false)
  )
})
