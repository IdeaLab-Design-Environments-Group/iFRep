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

