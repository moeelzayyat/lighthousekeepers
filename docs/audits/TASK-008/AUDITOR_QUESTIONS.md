# AUDITOR QUESTIONS — TASK-008

1. **Is R1 accepted as proof that the real module initializes cleanly?** It loaded, the probe wrote one key and the state became "Access", with the single caveat that `BindToClose` was not registered in Edit mode. Do you want a second R1-style check in a context where `BindToClose` works (a Play session or a published server) before any session test?
2. **The unguarded cached `require`.** Is this deviation acceptable as disclosed, or should the guard be hardened (for example by making the real module unreachable except through a function that also refuses cached returns, or by moving the real module out of `ServerStorage` until each approval)?
3. **Leaving the real module loaded.** It stays loaded in the open Studio session (empty autosave loop). Prefer restarting the SaveTest Studio window before R2?
4. **R2 scope.** Is "one fresh synthetic key, one start/save/end cycle in `TEST_LK_ProfileStore_v2`" the right next step, or do you want the legacy-record overwrite on a fixture key first, to see the real library behave as the mock did?
5. **Production API setting** remains owner-reported (off). Do you need an independent confirmation (for example a screenshot from the owner) before the next stage?
6. **Mock tests vs reality.** The cancellation behaviour (M3, M3b, M11, M11b) is established on fakes. Should those four be repeated on real DataStore keys in SaveTest before the adapter relies on them?

No other concern has been invented; items 2, 4 and 6 are the real forks.
