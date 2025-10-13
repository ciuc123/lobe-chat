# Vercel Build Memory Optimizations

## ✅ Current Status: BUILD SUCCESSFUL (8 min)

Applied optimizations:

- Disabled webpack persistent cache (saved 2.4 GB)
- Disabled all minification (saved 1.5 GB)
- Result: Build completes successfully within memory limits

## Optional Future Optimizations (Not Urgent)

### 1. Fix OpenTelemetry Warnings (Low Priority)

These warnings don't break the build but could be cleaned up:

**File**: `packages/obervability-otel/src/node.ts`

**Issue**: Missing optional peer dependencies:

- `@opentelemetry/winston-transport`
- `@opentelemetry/exporter-jaeger`

**Solutions** (choose one):
a) Install the missing packages if you use Winston logging or Jaeger tracing
b) Make these imports conditional/optional in the code
c) Ignore - they're warnings, not errors

### 2. Re-enable Minification Later (When Stable)

Once Vercel upgrades build machines or you optimize dependencies, you could:

**Re-enable client-side minification only**:

```typescript
// next.config.ts line 299
config.optimization.minimize = isServer ? false : true;
```

This would:

- Keep server bundles fast to build (unminified)
- Reduce client bundle sizes by 30-40%
- Add \~2-3 minutes to build time

**Trade-off**: Slightly longer builds, but better client performance

---

## Archived: Previous Contingency Levels (Not Needed)

### Level 1: Disable Client-Side Minification (APPLIED)

If the build fails again, disable ALL webpack minification to save \~1-2 GB memory during build.

**File: `next.config.ts` line 296-300**

Replace:

```typescript
// Disable minification for server bundles to save memory during build
if (config.optimization) {
  config.optimization.minimize = isServer ? false : config.optimization.minimize;
}
```

With:

```typescript
// Disable ALL minification during build to save memory
if (config.optimization) {
  config.optimization.minimize = false;
}
```

**Trade-off**: Larger client bundle size (\~30-40% increase), but build will complete.

---

### Level 2: Disable Emotion Compiler (Small Impact)

The Emotion CSS-in-JS compiler consumes memory during build.

**File: `next.config.ts` line 27-29**

Replace:

```typescript
compiler: {
  emotion: true,
},
```

With:

```typescript
compiler: isVercel
  ? {} // Disable emotion compiler on Vercel
  : { emotion: true },
```

**Trade-off**: Runtime emotion transforms, slightly slower initial render on Vercel.

---

### Level 3: Increase Memory Limit to 6GB (Infrastructure Change)

Requires updating the NODE_OPTIONS flag.

**File: `package.json` line 41**

Replace:

```json
"build:vercel": "cross-env NODE_OPTIONS=--max-old-space-size=5120 NEXT_DISABLE_SWC_WASM=1 next build",
```

With:

```json
"build:vercel": "cross-env NODE_OPTIONS=--max-old-space-size=6144 NEXT_DISABLE_SWC_WASM=1 next build",
```

**File: `vercel.json` line 2**

Replace:

```json
"buildCommand": "NODE_OPTIONS='--max-old-space-size=5120' pnpm run build:vercel",
```

With:

```json
"buildCommand": "NODE_OPTIONS='--max-old-space-size=6144' pnpm run build:vercel",
```

**Trade-off**: Uses 75% of 8GB machine memory (risky, may still OOM if OS needs memory).

---

### Level 4: Upgrade Vercel Build Machine (Last Resort)

Request Vercel Pro plan or contact support for larger build machines (16GB RAM available).

**Cost**: \~$20/month for Pro plan
**Benefit**: 2x memory, builds will succeed reliably

---

## Root Cause Summary

**Problem**: 3.3 GB node_modules + aggressive Next.js build = exceeds 8GB machine

**Primary Fix Applied**: Removed counterproductive chunk splitting (was creating 100+ chunks)

**Why It Should Work Now**:

- Removed \~1-2 GB memory overhead from excessive chunk metadata
- Still have all genuine memory optimizations active:
  - parallelism: 1 (no concurrent builds)
  - devtool: false (no source maps)
  - maxMemoryGenerations: 1 (minimal cache)
  - Server minification disabled
  - PWA plugin disabled on Vercel

**Estimated Memory Usage After Fix**: \~4-4.5 GB (within 5GB limit)

---

## Monitoring the Build

**Success indicators**:

- Build completes within 8-10 minutes
- No "JavaScript heap out of memory" errors
- Output files generated successfully

**Failure indicators**:

- Build time > 10 minutes suggests thrashing
- "Mark-Compact" GC messages in logs = approaching limit
- FATAL ERROR after 4-5 minutes = apply Level 1 optimization

---

## Long-term Solutions

1. **Dependency Audit**: Review if all 3,250 packages are necessary
2. **Monorepo Optimization**: Consider splitting into smaller deployable units
3. **Edge Runtime**: Move more routes to Edge runtime (lighter build)
4. **Incremental Static Regeneration**: Pre-build fewer pages, use ISR for rest

---

Generated: 2025-10-13
Applied: Level 0 (chunk splitting removal)
Next: Monitor current build, apply Level 1 if needed
