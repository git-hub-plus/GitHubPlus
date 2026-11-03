import { EventEmitter } from 'node:events'
import type { Socket } from 'node:dgram'
import { afterEach, expect, it, vi } from 'vitest'
import {
  announcement,
  broadcastAddresses,
  startAnnouncer,
} from '../../../../src/main/hub/server/announcer'

vi.mock('node:os', () => ({
  networkInterfaces: () => ({
    lan: [{ family: 'IPv4', address: '192.168.1.2', netmask: '255.255.255.0', internal: false }],
  }),
}))
afterEach(() => vi.useRealTimers())
it('encodes the discovery contract and computes subnet broadcasts', () => {
  expect(JSON.parse(announcement('Office', 8765, '1.0').toString())).toEqual({
    type: 'ghp-hub',
    name: 'Office',
    port: 8765,
    version: '1.0',
  })
  expect(
    broadcastAddresses({
      lan: [
        {
          family: 'IPv4',
          address: '192.168.4.3',
          netmask: '255.255.252.0',
          internal: false,
          cidr: null,
          mac: '',
        },
      ],
    })
  ).toEqual(['192.168.7.255'])
})
it('broadcasts every five seconds and stops with an injected socket', () => {
  vi.useFakeTimers()
  const socket = Object.assign(new EventEmitter(), {
    bind: (_port: number, callback: () => void) => callback(),
    setBroadcast: vi.fn(),
    send: vi.fn(),
    close: vi.fn(),
  })
  const stop = startAnnouncer('Office', 8765, '1.0', socket as unknown as Socket)
  expect(socket.setBroadcast).toHaveBeenCalledWith(true)
  const initial = socket.send.mock.calls.length
  expect(initial).toBe(1)
  expect(socket.send).toHaveBeenCalledWith(
    announcement('Office', 8765, '1.0'),
    47321,
    '192.168.1.255',
    expect.any(Function)
  )
  vi.advanceTimersByTime(10000)
  expect(socket.send.mock.calls.length).toBe(initial * 3)
  stop()
  vi.advanceTimersByTime(10000)
  expect(socket.send.mock.calls.length).toBe(initial * 3)
  expect(socket.close).toHaveBeenCalledOnce()
})
