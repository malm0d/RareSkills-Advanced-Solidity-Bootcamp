//import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
const StandardMerkleTree = require("@openzeppelin/merkle-tree").StandardMerkleTree;
const fs = require("fs");

//address, index
const data = [
    ["0x0000000000000000000000000000000000000001", "0"],
    ["0x0000000000000000000000000000000000000002", "1"],
    ["0x0000000000000000000000000000000000000003", "2"],
    ["0x0000000000000000000000000000000000000004", "3"],
    ["0x0000000000000000000000000000000000000005", "4"],
    ["0x0000000000000000000000000000000000000006", "5"],
    ["0x0000000000000000000000000000000000000007", "6"],
    ["0x0000000000000000000000000000000000000008", "7"],
    ["0x0000000000000000000000000000000000000009", "8"],
];

const merkleTree = StandardMerkleTree.of(data, ["address", "uint256"]);

console.log("Merkle root: ", merkleTree.root);

fs.writeFileSync("merkleTree.json", JSON.stringify(merkleTree.dump(), null, 2));

//root: 0xa297e088bf87eea455a2cbb55853136013d1f0c222822827516f97639984ec19