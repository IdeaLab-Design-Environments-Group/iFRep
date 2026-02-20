#!/usr/bin/env python3
#
# frep_multicore.py
#    functional representation solver (multithreaded)
#
# usage:
#    pcb.py | frep_multicore.py [dpi [filename]]
#    pcb.py | frep_multicore.py --c [dpi [filename]]   # generate C, compile, run (faster)
#
# Default: NumPy evaluation (works everywhere). With --c: generates C code,
# compiles with gcc/clang, runs multi-threaded native code, then cleans up.

import json
import sys
import os
import re
import subprocess
import tempfile
import shutil

# ---------------------------------------------------------------------------
# argv: optional --c / -c, then [dpi [filename]]
# ---------------------------------------------------------------------------
args = [a for a in sys.argv[1:] if a not in ('--c', '-c')]
use_c = ('--c' in sys.argv[1:]) or ('-c' in sys.argv[1:])

if len(args) == 0:
    dpi = 100
    filename = 'out.png'
elif len(args) == 1:
    dpi = int(args[0])
    filename = 'out.png'
else:
    dpi = int(args[0])
    filename = args[1]

frep = json.load(sys.stdin)

if frep.get('type') != 'RGB':
    print('types other than RGB not (yet) supported', file=sys.stderr)
    sys.exit(1)


def python_expr_to_c(fn):
    """Convert Python FRep expression string to C expression (scalar x,y,z)."""
    # Use scalar names in C
    fn = fn.replace('X', 'x').replace('Y', 'y').replace('Z', 'z')
    # math. -> nothing (C has sqrt, cos, sin, etc. in math.h)
    fn = fn.replace('math.', '')
    # math.pi -> M_PI (define _USE_MATH_DEFINES for some platforms)
    fn = re.sub(r'\bpi\b', 'M_PI', fn)
    # ** -> pow(left, right); handle multiple passes for a**b**c
    while '**' in fn:
        fn = re.sub(r'(\S+)\s*\*\*\s*(\d+\.?\d*|\w+(?:\.\w+)?)', r'pow(\1,\2)', fn, count=1)
    # Logical: & | ~ (Python style) -> && || !
    fn = fn.replace(' & ', ' && ')
    fn = fn.replace(' | ', ' || ')
    fn = fn.replace('~', '!')
    return fn


def run_c_backend(frep, dpi, filename):
    """Generate C source, compile, run, write PNG, cleanup."""
    xmin = frep['xmin']
    xmax = frep['xmax']
    ymin = frep['ymin']
    ymax = frep['ymax']
    units = float(frep['mm_per_unit'])
    zmin = min(frep['layers'])
    zmax = max(frep['layers'])
    fn = frep['function']
    fn_c = python_expr_to_c(fn)

    layers = frep['layers']
    layers_str = ','.join(str(z) for z in layers)
    nlayers = len(layers)

    delta = (25.4 / dpi) / units
    nx = int((xmax - xmin) / delta)
    ny = int((ymax - ymin) / delta)
    nthreads = os.cpu_count() or 1

    # Write into tmpdir with basename so we can move to user path after
    out_basename = os.path.basename(filename)
    filename_c = out_basename.replace('\\', '\\\\').replace('"', '\\"')

    c_src = f'''#define _USE_MATH_DEFINES
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <png.h>
#include <pthread.h>

static float xmin = {xmin};
static float xmax = {xmax};
static float ymin = {ymin};
static float ymax = {ymax};
static float zmin = {zmin};
static float zmax = {zmax};
static float units = {units};
static int dpi = {dpi};
static float delta = (25.4f/dpi)/units;
static int nx = {nx};
static int ny = {ny};
static int *m;
static float layers[] = {{{layers_str}}};
static int nlayers = {nlayers};
static int nthreads = {nthreads};
static const char *out_filename = "{filename_c}";

static int fn(float x, float y, float z) {{
   return ({fn_c});
}}

typedef struct {{ int thread_id; }} thread_arg_t;

static void *calc(void *arg) {{
   int thread = ((thread_arg_t*)arg)->thread_id;
   int intensity;
   for (int layer = 0; layer < nlayers; ++layer) {{
      float z = layers[layer];
      if (thread == 0)
         printf("   z = %g\\n", (double)z);
      if (zmin == zmax)
         intensity = 0xffffff;
      else
         intensity = ((int)(255*(z-zmin)/(zmax-zmin))) | (255 << 8) | (255 << 16);
      int iystart = thread * ny / nthreads;
      int iyend = (thread + 1) * ny / nthreads;
      for (int iy = iystart; iy < iyend; ++iy) {{
         float y = ymin + iy * delta;
         for (int ix = 0; ix < nx; ++ix) {{
            float x = xmin + ix * delta;
            m[iy*nx+ix] += (fn(x,y,z) ? intensity : 0);
         }}
      }}
   }}
   return NULL;
}}

int main(void) {{
   printf("   calculate %dx%d with %d threads\\n", nx, ny, nthreads);

   m = (int*)calloc((size_t)nx * ny, sizeof(int));
   if (!m) {{ perror("calloc"); return 1; }}

   pthread_t *threads = (pthread_t*)malloc((size_t)nthreads * sizeof(pthread_t));
   thread_arg_t *targs = (thread_arg_t*)malloc((size_t)nthreads * sizeof(thread_arg_t));
   if (!threads || !targs) {{ perror("malloc"); free(m); return 1; }}

   for (int i = 0; i < nthreads; ++i) {{
      targs[i].thread_id = i;
      pthread_create(&threads[i], NULL, calc, &targs[i]);
   }}
   for (int i = 0; i < nthreads; ++i)
      pthread_join(threads[i], NULL);

   FILE *file = fopen(out_filename, "wb");
   if (!file) {{ perror(out_filename); free(m); free(threads); free(targs); return 1; }}

   png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
   png_infop info = png_create_info_struct(png);
   png_init_io(png, file);
   png_set_IHDR(png, info, (png_uint_32)nx, (png_uint_32)ny, 8,
                PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE,
                PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
   png_set_pHYs(png, info, (png_uint_32)(1000*dpi/25.4), (png_uint_32)(1000*dpi/25.4), PNG_RESOLUTION_METER);
   png_write_info(png, info);

   png_bytep row = (png_bytep)malloc(4 * (size_t)nx);
   if (!row) {{ png_destroy_write_struct(&png, &info); fclose(file); free(m); free(threads); free(targs); return 1; }}
   for (int iy = ny - 1; iy >= 0; --iy) {{
      for (int ix = 0; ix < nx; ++ix) {{
         int v = m[iy*nx+ix];
         row[4*ix]   = (png_byte)(v & 255);
         row[4*ix+1] = (png_byte)((v >> 8) & 255);
         row[4*ix+2] = (png_byte)((v >> 16) & 255);
         row[4*ix+3] = 255;
      }}
      png_write_row(png, row);
   }}
   png_write_end(png, NULL);

   free(row);
   png_destroy_write_struct(&png, &info);
   fclose(file);
   free(m);
   free(threads);
   free(targs);
   printf("Saved: %s\\n", out_filename);
   return 0;
}}
'''

    tmpdir = tempfile.mkdtemp(prefix='frep_')
    c_path = os.path.join(tmpdir, 'frep.c')
    exe_path = os.path.join(tmpdir, 'frep-c')

    try:
        with open(c_path, 'w') as f:
            f.write(c_src)

        # sysconf for _SC_NPROCESSORS_ONLN needs _POSIX_C_SOURCE on some systems
        # Write a small wrapper that compiles with -D_POSIX_C_SOURCE=200809L
        for cc in ('gcc', 'clang'):
            cmd = [cc, '-o', exe_path, c_path, '-lm', '-lpng', '-pthread',
                   '-O3', '-ffast-math', '-D_POSIX_C_SOURCE=200809L']
            try:
                subprocess.run(cmd, check=True, capture_output=True, cwd=tmpdir)
                break
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
        else:
            print('error: need gcc or clang to compile C backend', file=sys.stderr)
            sys.exit(1)

        print('execute ...')
        subprocess.run([exe_path], check=True, cwd=tmpdir)

        # Move output PNG from tmpdir to user-requested path
        out_in_tmp = os.path.join(tmpdir, out_basename)
        if os.path.isfile(out_in_tmp):
            shutil.move(out_in_tmp, os.path.abspath(filename))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if use_c:
    if len(args) == 0:
        print('output to out.png at 300 DPI (C backend)')
        dpi = 300
        filename = 'out.png'
    elif len(args) == 1:
        print('output to out.png at', dpi, 'DPI (C backend)')
        filename = 'out.png'
    else:
        print('output to', filename, 'at', dpi, 'DPI (C backend)')
    print('compile ...')
    run_c_backend(frep, dpi, filename)
else:
    # NumPy path
    if len(args) == 0:
        print('output to out.png at 100 DPI')
    elif len(args) == 1:
        print('output to out.png at', dpi, 'DPI')
    else:
        print('output to', filename, 'at', dpi, 'DPI')

    from numpy import *
    from PIL import Image

    print('evaluating')
    xmin = frep['xmin']
    xmax = frep['xmax']
    ymin = frep['ymin']
    ymax = frep['ymax']
    units = float(frep['mm_per_unit'])
    delta = (25.4 / dpi) / units

    x = arange(xmin, xmax, delta)
    y = flip(arange(ymin, ymax, delta), 0)
    X = outer(ones(y.size), x)
    Y = outer(y, ones(x.size))

    num_threads = os.cpu_count() or 1
    print(f"   (NumPy using {num_threads} cores internally)")

    if len(frep['layers']) == 1:
        Z = frep['layers'][0]
        print("   z =", Z)
        f = eval(frep['function']).astype(uint32)
    else:
        f = zeros((y.size, x.size), dtype=uint32)
        zmin = min(frep['layers'])
        zmax = max(frep['layers'])
        for Z in frep['layers']:
            print("   z =", Z)
            i = int(255 * (Z - zmin) / (zmax - zmin)) | (255 << 8) | (255 << 16)
            flayer = i & (eval(frep['function'])).astype(uint32)
            f = f + flayer

    m = zeros((y.size, x.size, 3), dtype=uint8)
    m[:, :, 0] = (f & 255)
    m[:, :, 1] = ((f >> 8) & 255)
    m[:, :, 2] = ((f >> 16) & 255)
    im = Image.fromarray(m, 'RGB')
    im.save(filename, dpi=[dpi, dpi])
    print("Saved: " + filename)
