# Changelog

## [0.1.1](https://github.com/nycjv321/pickle-kit/compare/v0.1.0...v0.1.1) (2026-01-27)


### Features

* add CLI-based tag filtering via CUCUMBER_TAGS and CUCUMBER_EXCLUDE_TAGS environment variables ([375d765](https://github.com/nycjv321/pickle-kit/commit/375d76502603cda3b202c1fcbfe918f236c793d9))
* add HTML report generation with step-level results and timing ([483a7fd](https://github.com/nycjv321/pickle-kit/commit/483a7fd29fdc7ab3a7f00167ab8a5247b0cd870a))
* add todo editing support and fix defaultTestSuite crash ([a6a19a3](https://github.com/nycjv321/pickle-kit/commit/a6a19a3f049839e56b4fd1e950445f60f2200529))
* disable SwiftUI animations via launch argument ([4257fb8](https://github.com/nycjv321/pickle-kit/commit/4257fb84a44e933e2cd693006760e08068ef9f3e))
* extract TodoStore, add URL seed handler, and split CI pipeline ([1137bfc](https://github.com/nycjv321/pickle-kit/commit/1137bfc6ac2df9f385144c91926028f9026f0441))
* initial implementation of CucumberAndApples Swift Cucumber framework ([8df56b1](https://github.com/nycjv321/pickle-kit/commit/8df56b1f56d15f4568faeb93049f432cb3a2a634))
* optimize TodoApp UI tests with app reuse and improve docs ([295f946](https://github.com/nycjv321/pickle-kit/commit/295f946fa6ca97aaab95254159b51dd6b9a78ccb))
* rename to PickleKit and add TodoApp example ([1a64c0e](https://github.com/nycjv321/pickle-kit/commit/1a64c0ed80c430dd0a2d92d168034527cf3f1254))


### Bug Fixes

* align CI workflow with Harmonica's working test reporter pattern ([daee0f4](https://github.com/nycjv321/pickle-kit/commit/daee0f4cee380e1cd9d903941aa76d58dff3f595))
* **ci:** enable DevToolsSecurity and wait for accessibility on CI ([f98740e](https://github.com/nycjv321/pickle-kit/commit/f98740ed998f41189e74d4314555903109a32390))
* replace try! in StepRegistry.register() and wrap Task in do/catch ([d6c957e](https://github.com/nycjv321/pickle-kit/commit/d6c957e59f58252a338ee3fe83a8f59d922ec188))
* write xcbeautify JUnit report to working directory ([5beccd4](https://github.com/nycjv321/pickle-kit/commit/5beccd4f3aefb3effb462ca3c21764d3ad4f8674))


### Performance Improvements

* use pasteboard-based text entry in TodoApp UI tests ([6e3ccd2](https://github.com/nycjv321/pickle-kit/commit/6e3ccd2c146399f17bff870a68a561f0214cfc03))
