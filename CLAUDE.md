# Working on Kinu Tumble

## Tests

Do not run whole test suites after every code change. Run only the tests connected to what
changed: the scene under `tests/` that covers the touched script or screen (for example
`tests/my_kinu.tscn` for My Kinu, `tests/quest_clocks.tscn` for mission clocks). Run the full
`tests/integration.tscn` only when a change reaches across many systems or the user asks for it.
