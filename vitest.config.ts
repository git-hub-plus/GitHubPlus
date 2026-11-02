import { resolve } from 'node:path'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  resolve: {
    alias: {
      '@shared': resolve(__dirname, 'src/shared'),
      '@renderer': resolve(__dirname, 'src/renderer/src'),
    },
  },
  test: {
    include: ['tests/**/*.test.{ts,tsx}'],
    // Renderer tests opt into a DOM with a `// @vitest-environment jsdom` comment.
    environment: 'node',
  },
})
