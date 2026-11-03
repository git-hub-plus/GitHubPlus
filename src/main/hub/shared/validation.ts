import { isIP } from 'node:net'

/** LAN-only policy shared by the hub host and discovery client. */
export function isPrivateAddress(input: string): boolean {
  const address = input.toLowerCase().split('%')[0]
  if (address.startsWith('::ffff:')) {
    const suffix = address.slice(7)
    if (isIP(suffix) === 4) return isPrivateAddress(suffix)
    const parts = suffix.split(':')
    if (parts.length === 2 && parts.every((p) => /^[a-f0-9]{1,4}$/.test(p))) {
      const value = parseInt(parts[0], 16) * 65536 + parseInt(parts[1], 16)
      return isPrivateAddress(
        [value >>> 24, (value >>> 16) & 255, (value >>> 8) & 255, value & 255].join('.')
      )
    }
  }
  if (isIP(address) === 4) {
    const [a, b] = address.split('.').map(Number)
    return (
      a === 127 ||
      a === 10 ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 169 && b === 254)
    )
  }
  if (isIP(address) !== 6) return false
  const expanded = address.split('::')
  const words =
    expanded.length === 2
      ? [
          ...expanded[0].split(':').filter(Boolean),
          ...Array(8 - expanded.flatMap((p) => p.split(':').filter(Boolean)).length).fill('0'),
          ...expanded[1].split(':').filter(Boolean),
        ]
      : address.split(':')
  const numbers = words.map((p) => parseInt(p, 16))
  if (numbers.slice(0, 5).every((n) => n === 0) && numbers[5] === 0xffff) {
    return isPrivateAddress(
      [numbers[6] >>> 8, numbers[6] & 255, numbers[7] >>> 8, numbers[7] & 255].join('.')
    )
  }
  return (
    (numbers.slice(0, 7).every((n) => n === 0) && numbers[7] === 1) ||
    (numbers[0] & 0xfe00) === 0xfc00 ||
    (numbers[0] & 0xffc0) === 0xfe80
  )
}

export function isValidRepositoryName(name: unknown): name is string {
  return (
    typeof name === 'string' &&
    /^[a-zA-Z0-9_.-]{1,100}$/.test(name) &&
    !name.includes('..') &&
    !name.endsWith('.') &&
    !/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(name)
  )
}

/**
 * Preference order for LAN addresses shown to users and announced to clients:
 * home/office router ranges first, then other private IPv4, then IPv6.
 * Lower is better.
 */
export function lanAddressRank(address: string): number {
  const host = address.replace(/^\[|\]$/g, '')
  if (host.includes(':')) return (parseInt(host.split(':')[0], 16) & 0xffc0) === 0xfe80 ? 7 : 6
  const [a, b] = host.split('.').map(Number)
  if (a === 192 && b === 168) return 0
  if (a === 172 && b >= 16 && b <= 31) return 1
  if (a === 10) return 2
  if (a === 169 && b === 254) return 5
  return 4
}
