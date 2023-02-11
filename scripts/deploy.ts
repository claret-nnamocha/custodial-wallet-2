import { ethers } from 'hardhat'

async function main() {
  const WalletFactory = await ethers.getContractFactory('WalletFactory')
  const walletFactory = await WalletFactory.deploy()

  await walletFactory.deployed()

  console.log(`WalletFactory deployed to ${walletFactory.address}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
