iFRep: multicore FRep parser containing FRep based design attempt

## Quick run (simple example + C backend)

```bash
cd ifrep
python3 simple_pcb.py | python3 frep_multicore.py --c 300 simple.png
```

- **NumPy backend (no compiler):**  
  `python3 simple_pcb.py | python3 frep_multicore.py 300 simple.png`
- **Full PCB template:**  
  `python3 pcb.py | python3 frep_multicore.py --c [dpi [filename]]`

## Hybrid solver (frep_double.py)

**frep_double.py** implements a heterogeneous CPU–GPU-style pipeline that reduces work by refining only near boundaries:

1. **Coarse pass** — Evaluate the FRep at low resolution (e.g. 1/4) to get a low-res binary/mask. (In a full GPU setup this step runs on the GPU.)
2. **Boundary detection** — Find coarse cells where the value changes between neighbors (sign or inside/outside change); only these tiles need high resolution.
3. **Refinement** — Multi-threaded high-resolution evaluation **only** in those boundary tiles; uniform interior/exterior is skipped.
4. **Merge** — Upscale the coarse result to full size, then overwrite with the refined boundary tiles → full-resolution output.

The refinement step uses the same **C logic** as `frep_multicore.py` when you pass `--c`: expression-to-C conversion and the compiled multi-threaded evaluator.

**Usage:**

```bash
# Adaptive refinement (NumPy; no compiler)
python3 simple_pcb.py | python3 frep_double.py 300 out.png

# Coarse factor (default 4)
python3 simple_pcb.py | python3 frep_double.py --scale 4 300 out.png

# Use C for full-res evaluation after coarse/boundary (same C as frep_multicore)
python3 simple_pcb.py | python3 frep_double.py --c 300 out.png
```

- **Without --c:** Coarse and boundary detection run in Python; boundary tiles are refined with NumPy in parallel (multi-threaded).
- **With --c:** Coarse and boundary detection still run in Python; then the shared C backend (gcc/clang + libpng) does the full-resolution evaluation (same as `frep_multicore.py --c`).

