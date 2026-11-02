// Ported from GitHub Desktop (MIT): app/src/lib/git/git-delimiter-parser.ts
export function createLogParser<T extends Record<string, string>>(fields: T) {
  const keys = Object.keys(fields) as Array<keyof T>
  if (keys.length === 0) throw new Error('At least one log field is required')
  const formatArgs = ['-z', `--format=${Object.values(fields).join('%x00')}`]
  const parse = <V extends string | Buffer>(value: V): Array<{ [K in keyof T]: V }> => {
    const records: Array<string | Buffer> = []
    if (typeof value === 'string') records.push(...value.split('\0'))
    else {
      let start = 0
      for (let i = 0; i < value.length; i++)
        if (value[i] === 0) {
          records.push(value.subarray(start, i))
          start = i + 1
        }
      records.push(value.subarray(start))
    }
    const entries: Array<{ [K in keyof T]: V }> = []
    for (let i = 0; i + keys.length < records.length; i += keys.length) {
      const entry = {} as { [K in keyof T]: V }
      keys.forEach((key, index) => {
        entry[key] = records[i + index] as V
      })
      entries.push(entry)
    }
    return entries
  }
  return { formatArgs, parse }
}
