/** Record errors locally without transmitting reports. */
export async function reportError(
  error: Error,
  _extra?: { [key: string]: string },
  _nonFatal?: boolean
) {
  log.error('GitHub+ error (remote reporting disabled)', error)
}
