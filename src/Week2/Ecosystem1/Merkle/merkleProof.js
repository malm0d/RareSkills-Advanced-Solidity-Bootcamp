import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { fs } from "fs";

const merkleTree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync("merkleTree.json"))
);

for (const [i, v] of merkleTree.entires()) {
    if (v[0] === "0x0000000000000000000000000000000000000001") {
        const proof = tree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
}