# High Level Overview

## Project Overview
WhiteNoise is a secure messaging application built with Flutter & Rust, leveraging Nostr's decentralized infrastructure and the MLS protocol for secure, scalable messaging. The app will support iOS, Android, macOS, Linux, and Windows platforms.

## Core Architecture

### Rust Integration
- Core functionality implemented in a separate Rust crate
- Communication via Flutter-Rust bridge (FFI)
- Rust crate handles:
  - MLS protocol operations
  - Nostr protocol operations
  - Group management & data storage
  - Message encryption/decryption
  - Key management
  - Account & app settings management

### Flutter Application
- Primarily presentational layer
- Receives comprehensive state object from Rust layer
- Updates UI based on state changes and events
- Platform-specific UI components where appropriate
- Response design that works well on mobile screens but expands to two panel design (like most messengers) at wider screens on desktop.

## Key Features

### Authentication & Key Management
- Create new Nostr key pairs
- Import existing Nostr keys
- Secure storage of private keys using OS-specific secure storage
- Key export functionality for backup purposes
- Optimized onboarding that keeps technical details to an ABSOLUTE minimum. We should always strive to follow a progressive approach to onboarding. For example: No mention of keys or backups at the beginning. Just create a new "account" and start using the app (maybe with the option to give your account a name). As the user uses the app more (presumably getting more value from it) we recommend they back up their keys.

### Messaging
- DM & Group messaging with MLS protocol
- Rich group chats (replies, reactions, delete/edit messages, encrypted media with Blossom server backed)
- Message encryption/decryption
- Message delivery status (whether it was successfully published to nostr relays)
- Group management (create groups, add/remove member, update group details, change member admin status, etc)
- Joining groups view invites (join via kind:444 welcome messages, join via QR code shown in person)

### Relay Management
- Bootstrapping connection to initial relays
- Read and use user's nostr relays from relay lists
- User-configurable relay list in settings
- Per-group relay configuration
- Relay connection status monitoring
- Resilient handling of offline relays
- Ability to authenticate automatically to relays that require authentication

### Push Notifications
- We want to have optional push notifications available for users.
  - The most helpful (but least privacy preserving) will be the platform specific push notifications. Many users will be fine with these so they should be the default but not on by default.
  - We want to offer nostr specific solutions where possible. e.g. Android notifications via Pokey
  - We want to try and background poll when needed so that we can fetch new messages periodically if we don't have push notifications turned on

### Built-in wallet
- We want to allow users to send money via lightning or cashu in the app.
- We have a lot of exploration and design to do here before we start implementing but it's good to know that it's something we want to add.

### Future Considerations
- Offline message queuing
- Deep linking to contacts, groups, and individual messages.
- Message delivery retry mechanisms
- Advanced group management features

## Technical Considerations

### State Management
- To be determined (Bloc is where I'm currently leaning)
- Will need to handle:
  - Account State
    - What accounts are signed in
    - App settings for each account
    - Which is the active account currently being used
    - Methods will include signing in, creating new keypairs, signing out, switching the active user, updating settings.
  - Nostr State
    - Relays that are connected
    - What signer we are using (this ALWAYS matches the currently active account)
    - The nostr data cache (this is the rust nostr database that holds cached nostr events - this is shared between different accounts because all events in the cache are public)
    - Very few methods directly accessed. Mostly we access Nostr via specific actions on Groups, or Messages.
  - Groups state
    - What groups (DMs & groups of more than 2 people) is the user part of.
    - Lots of metadata about the groups (last message time, last message preview, member count, etc) so we can show rich previews and allow users to search for groups in the list.
    - Methods include; fetching groups, creating groups, changing groups, sending messages to groups, etc.
  - Message state
    - This is state that is probably only loaded when the user clicks into a group. Otherwise the state object would become HUGE.
    - Containts all the messages in the group - should only load most recent and then load on demand as the user scrolls back
    - Methods include; fetching messages
- Data is stored locally in Sqlite (accounts & mls) or LMDB (nostr data cache) databases. The flutter front-end never connects directly to the databases.

### Platform-Specific Implementation
- Native platform UI components (e.g. material for android, linux, and windows, cupertino for ios and macos) for:
  - Alerts
  - Dialogs
  - Form controls
  - Navigation patterns
  - etc.
- We want to store all nostr keys in the platform's secure storage if possible (flutter_secure_storage)

### Background Processing and App Lifecycle Management
- We will want to have long-running processes in the rust crate that subscribe to specific nostr events, process them, and then update the front-end as needed.
- We need to react to changes in the app lifecycle (app going into the background, etc) and shutdown those long-lived processes while also registering background tasks that are appropriate for the platform that we're on (e.g. iOS and Android) This will give us the best shot of being able to update users to new messages as they come in.

### Performance Requirements
- Efficient message loading and display
- Responsive UI (and loading indicators) during compute intensive operations
- Optimized relay connection management
- Efficient state updates

### Security Considerations
- Secure key storage (ideally using the platform specific secure storage mechanisms)
- End-to-end encryption
- Secure communication with relays
- Protection against common attack vectors
- Protection of user and group metadata

## Development Guidelines
- Follow platform-specific design patterns for common UI (alerts, dialogs, etc)
- Implement comprehensive error handling
- Maintain clear separation between Rust and Flutter layers
- Focus on performance and security
- Ensure high degree of test coverage
