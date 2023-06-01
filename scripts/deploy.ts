import { ethers, upgrades } from "hardhat";

// [admin, pauser, operator, toWrap, proxyAdmin]
const config = ['','','','','']

async function deploy() {
    console.log('Deploying...')
    const Wrapper = await ethers.getContractFactory("TokenWrapper")
    const wrap = await upgrades.deployProxy(Wrapper, config, {kind: 'uups'})
    await wrap.deployTransaction.wait()
    await wrap.deployed()
    console.log('Done.')

}

deploy()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });