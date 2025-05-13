# Rust API

## What is this about?

 This doc is a place to collect ideas and feedback on what the shape of the rust API should look like for the Flutter app. Currently the rust crate that is built into Tauri is doing a lot of things that I don't think we need to do here in Flutter. For example, there are about 50 commands that are quite Tuari or Svelte specific and I think we can get away from that and do something cleaner here.

## Why do we have a Rust crate in the app at all?

White Noise is implementing [NIP-EE](https://github.com/nostr-protocol/nips/pull/1427/files) to bring highly secure messaging (based on the MLS protocol) to Nostr. The main implementation of the MLS protocol is [OpenMLS](https://github.com/openmls/openmls) which is written in Rust. We also wrote a set of [rust crates](https://github.com/rust-nostr/nostr/tree/master/crates/nostr-mls) that wrap OpenMLS and provide the extra functionality required to make MLS function on Nostr. Because these crates are well tested and Rust is highly performant and type/memory safe, we'd like to continue using these crates to provide the core functionality to our apps. This also means that we're front-end independent. Want to drive White Noise via a CLI? We can do that. Want to use the crate to build a website? We can do that.

## How does the Flutter app talk to the Rust crate?

We're using [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) to automatically generate bindings from our rust code to this app.

## Application State

Since we'll be using Riverpod to create high-level providers that give access global state, we should be able to simplify the API significantly and depend on a high-level `StreamProvider` (or several) that provide updates from the backend to the front-end continuously.

### State Objects

TBD

## Needed Functionality

These aren't meant to be method signatures or the API itself, this is simply pseudo-methods (in the style of a REST API) that give us an idea of what we need. Much of this will likely be replaced by streamed state and providers.

### Accounts
- create_account()
- login(secret_key)
- logout(pub_key)
- get_active_account()
- get_accounts()
- get_account(pub_key)

### Groups

### Messages

### KeyPackages

### Welcomes


## The OLD API

This is a list of the current commands and what they do in the Tauri app. We should question whether we need each of these methods

### Groups

### Accounts

### Messages

### KeyPackages

### Welcomes

###
