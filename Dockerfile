# Two stages: the build image carries Elixir and the toolchain, the runtime
# carries only the release and the libraries it links against. Pinned by digest
# tag rather than `latest`, so a rebuild months from now produces the same
# image as today.
ARG BUILDER_IMAGE="hexpm/elixir:1.18.0-erlang-27.3.4.3-debian-bookworm-20250929-slim"
ARG RUNNER_IMAGE="debian:bookworm-20260918-slim"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y \
  && apt-get install -y build-essential git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Dependencies first, so a change to application code does not invalidate the
# compiled deps layer.
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# The release ships its own Erlang, but the OS still has to agree on UTF-8 or
# every accented character in the content comes out mangled.
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/blogo ./

USER nobody

# webo's tunnel routes every app to <slug>:3000 on the shared network, and the
# port is not configurable per project. The release binds 0.0.0.0 already; a
# server on loopback here would show a healthy container and a 502.
ENV PORT=3000
EXPOSE 3000

CMD ["/app/bin/server"]
