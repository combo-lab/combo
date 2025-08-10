/* global process */

import { context, build } from 'esbuild'

const outdir = '../priv/static'

function createBuilds(entrypoint, outdir, builds) {
  const baseOptions = {
    entryPoints: [entrypoint],
  }

  return Object.entries(builds).map(([outfile, options]) => {
    return {
      outfile: `${outdir}/${outfile}`,
      ...baseOptions,
      ...options,
    }
  })
}

const socketBuilds = createBuilds('./src/socket', outdir, {
  'socket.esm.js': {
    format: 'esm',
    platform: 'neutral',
    bundle: true,
    sourcemap: true,
  },
  'socket.cjs.js': {
    format: 'cjs',
    platform: 'node',
    bundle: true,
    sourcemap: true,
  },
  'socket.js': {
    format: 'iife',
    platform: 'browser',
    target: 'es2016',
    bundle: true,
    sourcemap: true,
    globalName: 'Combo.Socket',
  },
  'socket.min.js': {
    format: 'iife',
    platform: 'browser',
    target: 'es2016',
    bundle: true,
    sourcemap: true,
    minify: true,
    globalName: 'Combo.Socket',
  },
})

const htmlBuilds = createBuilds('./src/html', outdir, {
  'html.esm.js': {
    format: 'esm',
    platform: 'neutral',
    bundle: true,
    sourcemap: true,
  },
  'html.cjs.js': {
    format: 'cjs',
    platform: 'node',
    bundle: true,
    sourcemap: true,
  },
  'html.js': {
    format: 'iife',
    platform: 'browser',
    target: 'es2016',
    bundle: true,
    sourcemap: true,
    globalName: 'Combo.HTML',
  },
  'html.min.js': {
    format: 'iife',
    platform: 'browser',
    target: 'es2016',
    bundle: true,
    sourcemap: true,
    minify: true,
    globalName: 'Combo.HTML',
  },
})

const builds = [...socketBuilds, ...htmlBuilds]

// Check if we should watch or build once
const isWatch = process.argv.includes('--watch') || process.argv.includes('-w')

// Enhanced logging utilities
function formatTime() {
  return new Date().toLocaleTimeString('en-US', {
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })
}

function getOutputFileName(config) {
  return config.outfile.split('/').pop()
}

// Build all configurations
async function main() {
  try {
    if (isWatch) {
      const contexts = await Promise.all(
        builds.map(async (config) => {
          const outputName = getOutputFileName(config)

          const enhancedConfig = {
            ...config,
            plugins: [
              {
                name: 'watch-logger',
                setup(build) {
                  build.onStart(() => {
                    console.log(`[${formatTime()}] 🔄 Rebuilding ${outputName}`)
                  })

                  build.onEnd((result) => {
                    if (result.errors.length > 0) {
                      console.log(`[${formatTime()}] ❌ ${outputName} - Build failed`)
                      result.errors.forEach(error => {
                        console.error(`  └─ ${error.text}`)
                        if (error.location) {
                          console.error(`     at ${error.location.file}:${error.location.line}:${error.location.column}`)
                        }
                      })
                    } else if (result.warnings.length > 0) {
                      console.log(`[${formatTime()}] ⚠️  ${outputName} - Built with warnings`)
                      result.warnings.forEach(warning => {
                        console.warn(`  └─ ${warning.text}`)
                        if (warning.location) {
                          console.warn(`     at ${warning.location.file}:${warning.location.line}:${warning.location.column}`)
                        }
                      })
                    } else {
                      console.log(`[${formatTime()}] ✅ Built ${outputName} successfully`)
                    }
                  })
                }
              },
              ...(config.plugins || [])
            ]
          }

          return await context(enhancedConfig)
        })
      )

      console.log('👀 Watching for changes... (Press Ctrl+C to stop)')
      await Promise.all(contexts.map(ctx => ctx.watch()))

      // Handle graceful shutdown
      process.on('SIGINT', async () => {
        console.log('\n🛑 Stopping watchers...')
        await Promise.all(contexts.map(ctx => ctx.dispose()))
        process.exit(0)
      })
    } else {
      console.log(`🔨 Building...`)
      await Promise.all(builds.map(config => build(config)))
      console.log('✅ All builds completed successfully')
    }
  }
  catch (error) {
    console.error('❌ Build failed:', error)
    process.exit(1)
  }
}

main()
