import numpy as np
import ssm

m = ssm.SLDS(15, 2, 5, M=8, transitions="recurrent", dynamics="diagonal_gaussian",
             emissions="gaussian_orthog", single_subspace=True)
print("dynamics type:", type(m.dynamics).__name__)
print("dynamics attrs:", sorted(vars(m.dynamics).keys()))
print("transitions attrs:", sorted(vars(m.transitions).keys()))
Y = np.random.randn(300, 15)
u = np.random.randn(300, 8)
m.initialize(Y, inputs=u)
print()
print("after initialize:")
for k in ("As", "bs", "Bs", "sigmasq"):
    v = getattr(m.dynamics, k, None)
    print("  dynamics.%s -> %s" % (k, None if v is None else np.shape(v)))
for k in ("Rs", "Ws"):
    v = getattr(m.transitions, k, None)
    print("  transitions.%s -> %s" % (k, None if v is None else np.shape(v)))
