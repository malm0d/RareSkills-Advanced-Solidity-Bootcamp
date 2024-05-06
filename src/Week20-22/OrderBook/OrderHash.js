const ethers = require('ethers');

//node src/Week20-22/OrderBook/OrderHash.js
//Solidity Structs:
// struct Order {
//     address maker;
//     uint256 deadline;
//     address sellToken;
//     address buyToken;
//     uint256 sellTokenAmount;
//     uint256 buyTokenAmount;
//     uint256 nonce;
// }
// struct Permit {
//     address tokenAddr;
//     address owner; //`owner` of the tokens
//     uint256 value;
//     uint256 deadline;
//     uint8 v;
//     bytes32 r;
//     bytes32 s;
// }

const STRUCTS = {
    Order: [
        {
            name: 'maker',
            type: 'address'
        },
        {
            name: 'deadline',
            type: 'uint256'
        },
        {
            name: 'sellToken',
            type: 'address'
        },
        {
            name: 'buyToken',
            type: 'address'
        },
        {
            name: 'sellTokenAmount',
            type: 'uint256'
        },
        {
            name: 'buyTokenAmount',
            type: 'uint256'
        },
        {
            name: 'nonce',
            type: 'uint256'
        }
    ],
    Permit: [
        {
            name: 'tokenAddr',
            type: 'address'
        },
        {
            name: 'owner',
            type: 'address'
        },
        {
            name: 'value',
            type: 'uint256'
        },
        {
            name: 'deadline',
            type: 'uint256'
        },
        {
            name: 'v',
            type: 'uint8'
        },
        {
            name: 'r',
            type: 'bytes32'
        },
        {
            name: 's',
            type: 'bytes32'
        }
    ]
}

const sampleOrder = {
    maker: ethers.ZeroAddress,
    deadline: 0,
    sellToken: ethers.ZeroAddress,
    buyToken: ethers.ZeroAddress,
    sellTokenAmount: 0,
    buyTokenAmount: 0,
    nonce: 0
}

const samplePermit = {
    tokenAddr: ethers.ZeroAddress,
    owner: ethers.ZeroAddress,
    value: 0,
    deadline: 0,
    v: 0,
    r: ethers.ZeroHash,
    s: ethers.ZeroHash
}

//Ethers: ethers.TypedDataEncoder.hashStruct(string, Record<string, Array<TypedDataField>, Record<string, any>) => string
const orderHash = ethers.TypedDataEncoder.hashStruct('Order', { Order: STRUCTS.Order }, sampleOrder);
console.log("OrderHash: ", orderHash);

const permitHash = ethers.TypedDataEncoder.hashStruct('Permit', { Permit: STRUCTS.Permit }, samplePermit);
console.log("PermitHash: ", permitHash);

//Output:
// OrderHash:  0x499edbadcbe75d59d7867b69a8fce8755f1843d9ddab6b2a8047db0bf2c20765
// PermitHash:  0x6f4abe71d94c8606ef8f2efec36e5cdcc9bf1923a2129a6dbea9b902bbc165ae

//(https://docs.ethers.org/v6/api/providers/#Signer-signTypedData)
//Typically, to sign a message: 
//
//1. Define domain separator
// const eip712Domain = {
//     name: 'OrderBook',
//     version: '1',
//     chainId: 1,  // Use the correct chainId for your deployment
//     verifyingContract: '0xContractAddress'  // Replace with your contract's address
// };
//
//2. Define the EIP-712 typed data
// In this case we can use the same STRUCTS.Order and STRUCTS.Permit
//
//3. Obtain the data
// In this case we can use the sampleOrder and samplePermit
//
//4. Sign the data
// Use signer.signTypedData:
// const signature = await signer.signTypedData(eip712Domain, { Order: STRUCTS.Order }, sampleOrder);