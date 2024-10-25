---
title: "Fast k8s Context and Namespace Switching With Kubectx Kubens"
date: 2024-10-25T23:15:35+02:00
tags: ["kubernetes"]
---

[`kubectx` and `kubens`](https://github.com/ahmetb/kubectx) are both great tools which speeds up working with multiple Kubernetes clusters. kubectx allows quickly changing [context](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/). kubens allows changing [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) in given context.

## kubectx

With kubectl you need to type

```shell
kubectl config use-context my-context
```

With kubectx

```shell
kubectx my-context
```

If you have [`fzf`](https://github.com/junegunn/fzf) installed, you can interactively select cluster by just writing `kubectx`.

## kubens

Kubens is similar but it allows setting namespace. Instead of doing

```shell
kubectl config set-context --current --namespace=my-namespace
```

You can do

```shell
kubens my-namespace
```

Fzf selection works here as well.

## Installation

For Mac, if you are using [Homebrew](https://brew.sh), it is as simple as doing

```shell
brew install kubectx
```

For other platforms, you can referer [here](https://github.com/ahmetb/kubectx?tab=readme-ov-file#installation).
