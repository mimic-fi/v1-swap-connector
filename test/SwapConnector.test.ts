import { deploy, ZERO_ADDRESS } from '@mimic-fi/v1-helpers'
import { expect } from 'chai'
import { Contract } from 'ethers'

describe('SwapConnector', () => {
  let connector: Contract

  beforeEach('create connector', async () => {
    connector = await deploy('SwapConnector', [ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS])
  })

  it('uses Uniswap V2 by default', async () => {
    expect(await connector.getPathDex(ZERO_ADDRESS, ZERO_ADDRESS)).to.be.equal(0)
  })
})
