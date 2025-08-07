import { build } from "esbuild"

const outdir = "../priv/static"

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

const socketBuilds = createBuilds("./src/socket", outdir, {
  "socket.esm.js": {
    format: "esm",
    platform: "neutral",
    bundle: true,
    sourcemap: true,
  },
  "socket.cjs.js": {
    format: "cjs",
    platform: "node",
    bundle: true,
    sourcemap: true,
  },
  "socket.js": {
    format: "iife",
    platform: "browser",
    target: "es2016",
    bundle: true,
    sourcemap: true,
    globalName: "Combo.Socket",
  },
  "socket.min.js": {
    format: "iife",
    platform: "browser",
    target: "es2016",
    bundle: true,
    sourcemap: true,
    minify: true,
    globalName: "Combo.Socket",
  }
})

const htmlBuilds = createBuilds("./src/html", outdir, {
  "html.esm.js": {
    format: "esm",
    platform: "neutral",
    bundle: true,
    sourcemap: true,
  },
  "html.cjs.js": {
    format: "cjs",
    platform: "node",
    bundle: true,
    sourcemap: true,
  },
  "html.js": {
    format: "iife",
    platform: "browser",
    target: "es2016",
    bundle: true,
    sourcemap: true,
    globalName: "Combo.HTML",
  },
  "html.min.js": {
    format: "iife",
    platform: "browser",
    target: "es2016",
    bundle: true,
    sourcemap: true,
    minify: true,
    globalName: "Combo.HTML",
  }
})

const builds = [...socketBuilds, ...htmlBuilds]

// Build all configurations
async function buildAll() {
  try {
    console.log("🔨 Building Combo...")
    await Promise.all(builds.map((config) => build(config)))
    console.log("✅ All builds completed successfully")
  } catch (error) {
    console.error("❌ Build failed:", error)
    process.exit(1)
  }
}

buildAll()
