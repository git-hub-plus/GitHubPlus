import { createSocket } from 'node:dgram'
import { networkInterfaces, type NetworkInterfaceInfo } from 'node:os'
import { isPrivateAddress } from '../shared/validation'

export function announcement(name: string, port: number, version: string): Buffer {
  return Buffer.from(JSON.stringify({ type: 'ghp-hub', name, port, version }))
}

export function broadcastAddresses(
  interfaces: NodeJS.Dict<NetworkInterfaceInfo[]> = networkInterfaces()
): string[] {
  return [
    ...new Set(
      Object.values(interfaces).flatMap((entries) =>
        (entries ?? [])
          .filter((i) => i.family === 'IPv4' && !i.internal && isPrivateAddress(i.address))
          .map((i) => {
            const ip = i.address.split('.').map(Number)
            return i.netmask
              .split('.')
              .map((part, index) => ip[index] | (~Number(part) & 255))
              .join('.')
          })
      )
    ),
  ]
}

export function startAnnouncer(
  name: string,
  port: number,
  version: string,
  socket = createSocket('udp4')
): () => void {
  let timer: ReturnType<typeof setInterval> | undefined
  let stopped = false
  socket.on('error', () => {
    /* Discovery is best effort; HTTP remains available. */
  })
  socket.bind(0, () => {
    if (stopped) return
    socket.setBroadcast(true)
    const send = (): void => {
      for (const address of broadcastAddresses())
        socket.send(announcement(name, port, version), 47321, address, () => {})
    }
    send()
    timer = setInterval(send, 5000)
    timer.unref()
  })
  return () => {
    if (stopped) return
    stopped = true
    if (timer) clearInterval(timer)
    socket.close()
  }
}
