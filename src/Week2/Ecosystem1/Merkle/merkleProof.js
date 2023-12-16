// import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
// import { fs } from "fs";
const StandardMerkleTree = require("@openzeppelin/merkle-tree").StandardMerkleTree;
const fs = require("fs");

//node src/Week2/Ecosystem1/Merkle/merkleProof.js
const merkleTree = StandardMerkleTree.load(
    JSON.parse(fs.readFileSync(process.cwd() + "/src/Week2/Ecosystem1/Merkle/merkleTree.json", "utf8"))
);

for (const [i, v] of merkleTree.entries()) {
    if (v[0] === "0x0000000000000000000000000000000000000001") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000002") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000003") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000004") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000005") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000006") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000007") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000008") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
    if (v[0] === "0x0000000000000000000000000000000000000009") {
        const proof = merkleTree.getProof(i);
        console.log("Merkle proof:", proof);
        console.log("Value:", v);
    }
}

//   Merkle proof: [
//     '0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c',
//     '0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19',
//     '0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd'
//   ]
//   Value: [ '0x0000000000000000000000000000000000000001', '0' ]
//
//   Merkle proof: [
//     '0x5fa3dab1e0e1070445c119c6fd10edd16d6aa2f25a5899217f919c041d474318',
//     '0x895c5cff012220658437b539cdf2ce853576fc0a881d814e6c7da6b20e9b8d8d',
//     '0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd'
//   ]
//   Value: [ '0x0000000000000000000000000000000000000002', '1' ]