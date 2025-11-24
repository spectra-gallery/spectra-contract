// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library GenerativeLib {
    struct Genome {
        bytes32 seed;
        uint256 entropy;     // 0..1e18 (fixed-point 1e18)
        uint256 coherence;   // 0..1e18
        uint256 rhythm;      // 0..1e18
        uint256 hue;         // 0..36000 (two decimals)
        uint256 dopamine;    // 0..1e18
    }

    function _u64(bytes32 s, uint256 i) private pure returns (uint64 x) {
        unchecked {
            uint256 o = i * 8;
            x = uint64(uint256(s >> (o * 8)));
        }
    }

    function _norm(bytes32 s, uint256 i) private pure returns (uint256) {
        // map to [0, 1e18]
        uint64 v = _u64(s, i);
        return (uint256(v) * 1e18) / type(uint64).max;
    }

    function _angle(bytes32 s, uint256 i) private pure returns (uint256) {
        // map to [0, 36000] (two decimals precision)
        uint64 v = _u64(s, i);
        return (uint256(v) * 36000) / type(uint64).max;
    }

    function seedFor(
        uint256 tokenId,
        bytes32 tokenHash,
        address minter
    ) internal view returns (bytes32) {
        // Simulated "quantum field" PRNG: mix multiple on-chain sources
        // Note: not secure randomness for high-stakes; adequate for art params.
        return keccak256(
            abi.encode(
                tokenId,
                tokenHash,
                block.prevrandao,
                blockhash(block.number - 1),
                block.timestamp,
                gasleft(),
                minter
            )
        );
    }

    function genomeFromSeed(bytes32 seed) internal pure returns (Genome memory g) {
        g.seed = seed;
        g.entropy = _norm(seed, 0);
        g.coherence = _norm(seed, 1);
        g.rhythm = _norm(seed, 2);
        g.hue = _angle(seed, 3);
        // Dopamine as a simple function of entropy and coherence interplay
        g.dopamine = (g.entropy + (1e18 - g.coherence)) / 2;
    }
}

