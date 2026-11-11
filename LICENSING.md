# Licensing

EnvoScale is **free for individuals and noncommercial use**. **Companies need a
commercial license.** The legal terms are in [`LICENSE`](LICENSE); this page explains
them in plain words. If this page and `LICENSE` ever disagree, `LICENSE` wins.

> EnvoScale is *source-available*, not *open source* in the OSI sense: anyone can read,
> build, change and learn from the code, but commercial use is licensed separately.

## Which license do I need?

| You are… | You may use EnvoScale under | Cost |
|---|---|---|
| An individual learning, experimenting, or building personal or hobby projects | Community License (PolyForm Noncommercial 1.0.0) | Free |
| A student, teacher, school, university or public research institution | Community License | Free |
| A charity, public-health, public-safety or environmental organization, or a government institution | Community License | Free |
| A company, of any size, using EnvoScale for its work, product or services | **Commercial License** | Paid |
| An individual using EnvoScale to earn money (freelance work, a paid product, a commercial service) | **Commercial License** | Paid |

When in doubt, you need a commercial license, or you can ask (see below).

## What each license covers

### Community License

- Use, build, modify and share EnvoScale for noncommercial purposes.
- Programs you build for those purposes are yours, and you can share them for
  noncommercial use.
- No warranty and no support guarantees. Community help is best-effort through the
  repository's issues.

### Commercial License

- Use of EnvoScale by your organization for any purpose, including in products and
  services you sell, and internal tools.
- Distribution of programs built with EnvoScale. Compiled programs contain parts of the
  EnvoScale runtime and standard platform, so shipping them commercially is part of
  what the commercial license grants.
- Planned enterprise terms (see [Enterprise](#enterprise)): support with response times,
  long-term-support releases, security advisories ahead of public disclosure, and
  indemnification, as agreed in the license agreement.

## Programs you build with EnvoScale

Your own source code belongs to you under either license. The compiled output also
contains EnvoScale's runtime and standard platform code, which is licensed to you on the
same terms as the toolchain you built it with:

- built under the Community License → usable and shareable for noncommercial purposes;
- built under a Commercial License → usable and distributable commercially, as your
  agreement says.

## Enterprise

EnvoScale is being built to be enterprise-ready by the end of its roadmap: reproducible
and signed releases, a software bill of materials for every build, long-term-support
releases, a published security response process, offline installation, and a private
package registry option. Progress is tracked under the **Enterprise readiness** milestone
on the [roadmap project](https://github.com/orgs/envoscale/projects/3).

## Getting a commercial license

Contact the copyright holder through the [envoscale organization on
GitHub](https://github.com/envoscale). Commercial license agreements are written per
customer until standard terms are published.

## Contributing

Contributions are accepted under the [Contributor License Agreement](CLA.md), which
lets the project offer contributed work under both licenses.

## Why this model

The Community License keeps EnvoScale free for the people the project is built for at
skill levels 0–4: beginners, students, researchers and hobbyists. Commercial licenses
fund full-time work on the compiler, the standard platform, security audits (for
example of `envo.crypto`, see [`SECURITY.md`](SECURITY.md)) and long-term support.
