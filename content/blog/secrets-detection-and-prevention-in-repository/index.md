---
title: "Secrets Detection and Prevention in Repository"
date: 2024-10-27T11:56:25+01:00
---

I decided to make blog repository public to allow writing comments. In order to do it, I scanned my repo using two programs.

## detect-secrets
[detect-secrets](https://github.com/Yelp/detect-secrets) detects secrets within a code base however, unlike other similar packages that solely focus on finding secrets, this package is designed with the enterprise client in mind: providing a **backwards compatible**, systematic means of:

1. Preventing new secrets from entering the code base,
2. Detecting if such preventions are explicitly bypassed, and
3. Providing a checklist of secrets to roll, and migrate off to a more secure storage.

to install 

```
brew install detect-secrets
```

to use
```
# create base line
detect-secrets scan > .secrets.baseline
# review secrets
detect-secrets audit .secrets.baseline
```

Output
```

Secret:      5 of 5
Filename:    content/blog/zerolog-trace-id-access-log/index.md
Secret Type: Hex High Entropy String
----------
123:                "TraceState": "",
124:                "Remote": false
125:        },
126:        "Parent": {
127:                "TraceID": "5fdc14f10cb4c2d1f253f853c16162e7",
128:                "SpanID": "47e1ebf518ef9e7d",
129:                "TraceFlags": "01",
130:                "TraceState": "",
131:                "Remote": false
132:        },
133:        "SpanKind": 1,
----------
```

## gitleaks

[gitleaks](https://github.com/gitleaks/gitleaks) is another tool for the same job. Gitleaks is a Static application security testing tool for **detecting** and **preventing** hardcoded secrets like passwords, API keys, and tokens in git repos. Gitleaks is an easy-to-use, all-in-one solution for detecting secrets, past or present, in your code.

```
brew install gitleaks
```

```
gitleaks git -v

    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

11:54AM INF 47 commits scanned.
11:54AM INF scan completed in 166ms
11:54AM INF no leaks found
```
## Adding to pre-commit

Using `pre-commit` is a great way to speed up find errors before doing the commit. 

```yaml
# .pre-commit-config.yaml
repos:
-   repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
    -   id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package.lock.json
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.19.0
    hooks:
      - id: gitleaks
```
