# How can OpenSea quickly determine which NFTs an address owns if most NFTs don’t use ERC721 enumerable? Explain how you would accomplish this if you were creating an NFT marketplace

Link: https://www.rareskills.io/post/ethereum-events

For efficient enumeration of all tokens in an NFT collection, ERC721Enumerable contains the follwoing functions to make it easy to identify NFT ownership:
- `totalSupply`
- `tokenByIndex`
- `tokenOfOwnerByIndex`

Without ERC721 Enumerable, we can rely on events to accomplish the same thing. With an Ethereum client, we can use `events`, `events.allEvents`, and `getPastEvents`, together with the addresses of the smart contracts we wish to inspect events for, to extract emitted events logged by the contracts.

When a trade occurs for an NFT, a `Transfer` event is emitted which logs the `from` address, `to` address, and the `tokenId` of the ERC721 token.

Side note, events emitted from smart contracts are stored in a Bloom Filter (probabilistic set) to allow the client to scan the entire blockchain rapidly to look for specific events.

On that note, NFT marketplaces like OpenSea likely have services to monitor the events/logs emitted by known NFT contracts on Ethereum. And they also likely have a database and a cache of data to store and update all this information to enable faster data queries.

I would probably do the same thing as OpenSea does, because its the most efficient way to do so to find the owners of NFTs from collections that do not implement ERC721 Enumerable.