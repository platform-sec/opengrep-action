# SPDX-License-Identifier: MIT

# Local `act` runner image.
#
# act's stock image is a subset of the GitHub-hosted ubuntu runner, so an
# action that works in CI can still fail locally on a missing base package.
# This layer adds back only what the action's dependencies actually need, so
# local runs exercise the same code path CI does instead of a variant with
# security steps disabled.
#
# gettext-base -> envsubst, used by sigstore/cosign-installer. Present on
#                 GitHub-hosted runners, absent from the act image.
#
# Built by `just build-act-image` and referenced from .actrc.
ARG BASE_IMAGE=catthehacker/ubuntu:act-22.04
FROM ${BASE_IMAGE}

RUN apt-get update \
    && apt-get install -y --no-install-recommends gettext-base \
    && rm -rf /var/lib/apt/lists/*
