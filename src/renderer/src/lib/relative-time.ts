import { getLocale } from '@shared/i18n'

export function relativeTime(date: number, now = Date.now()): string {
  const seconds = (date - now) / 1000
  const units: ReadonlyArray<readonly [Intl.RelativeTimeFormatUnit, number]> = [
    ['year', 31536000],
    ['month', 2592000],
    ['week', 604800],
    ['day', 86400],
    ['hour', 3600],
    ['minute', 60],
    ['second', 1],
  ]
  const [unit, size] =
    units.find(([, size]) => Math.abs(seconds) >= size) ?? units[units.length - 1]
  return new Intl.RelativeTimeFormat(getLocale(), { numeric: 'auto' }).format(
    Math.round(seconds / size),
    unit
  )
}
