import { deploy, fp, impersonate, instanceAt, MAX_UINT256 } from '@mimic-fi/v1-helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { BigNumber, Contract } from 'ethers'

describe('SwapConnector', () => {
  let connector: Contract, priceOracle: Contract, weth: Contract, usdc: Contract, whale: SignerWithAddress

  const amountIn = fp(5)
  const slippage = fp(0.02)
  let expectedMinAmountOut: BigNumber

  /* eslint-disable no-secrets/no-secrets */

  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
  const USDC = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
  const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F'
  const WHALE_WITH_WETH = '0x4a18a50a8328b42773268B4b436254056b7d70CE'

  const UNISWAP_V2_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
  const UNISWAP_V3_ROUTER = '0xE592427A0AEce92De3Edee1F18E0157C05861564'
  const BALANCER_V2_VAULT = '0xBA12222222228d8Ba445958a75a0704d566BF2C8'

  const UNISWAP_V3_FEE = 3000
  const CHAINLINK_ORACLE_USDC_WETH = '0x986b5E1e1755e3C2440e960477f25201B0a8bbD4'
  const BALANCER_POOL_USDC_WETH_ID = '0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019'
  const BALANCER_POOL_USDC_DAI_ID = '0x06df3b2bbb68adc8b0e302443692037ed9f91b42000000000000000000000063'
  const BALANCER_POOL_DAI_WETH_ID = '0x0b09dea16768f0799065c475be02919503cb2a3500020000000000000000001a'

  before('create price oracle', async () => {
    const priceOracleTokens: string[] = [USDC, WETH]
    const priceOracleFeeds: string[] = [CHAINLINK_ORACLE_USDC_WETH, '0x1111111111111111111111111111111111111111']
    priceOracle = await deploy(
      '@mimic-fi/v1-chainlink-price-oracle/artifacts/contracts/ChainLinkPriceOracle.sol/ChainLinkPriceOracle',
      [priceOracleTokens, priceOracleFeeds]
    )
  })

  before('create swap connector', async () => {
    const args = [priceOracle.address, UNISWAP_V3_ROUTER, UNISWAP_V2_ROUTER, BALANCER_V2_VAULT]
    connector = await deploy('SwapConnector', args)
  })

  before('load tokens', async () => {
    weth = await instanceAt('IERC20', WETH)
    usdc = await instanceAt('IERC20', USDC)
  })

  before('impersonate whale', async () => {
    whale = await impersonate(WHALE_WITH_WETH, fp(100))
  })

  beforeEach('compute expected amount out', async () => {
    const price = await priceOracle.getTokenPrice(USDC, WETH)
    const expectedAmountOut = price.mul(amountIn).div(fp(1))
    expectedMinAmountOut = expectedAmountOut.sub(expectedAmountOut.mul(slippage).div(fp(1)))
  })

  it('can swap with Uniswap V2', async () => {
    await connector.setUniswapV2Path(USDC, WETH)

    const previousBalance = await usdc.balanceOf(whale.address)
    await weth.connect(whale).transfer(connector.address, amountIn)
    await connector.connect(whale).swap(WETH, USDC, amountIn, 0, MAX_UINT256, '0x')
    const currentBalance = await usdc.balanceOf(whale.address)
    expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
  })

  it('can swap with Uniswap V3', async () => {
    await connector.setUniswapV3Path(WETH, USDC, UNISWAP_V3_FEE)

    const previousBalance = await usdc.balanceOf(whale.address)
    await weth.connect(whale).transfer(connector.address, amountIn)
    await connector.connect(whale).swap(WETH, USDC, amountIn, 0, MAX_UINT256, '0x')
    const currentBalance = await usdc.balanceOf(whale.address)
    expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
  })

  it('can swap with Balancer V2', async () => {
    await connector.setBalancerV2Path(WETH, USDC, BALANCER_POOL_USDC_WETH_ID)

    const previousBalance = await usdc.balanceOf(whale.address)
    await weth.connect(whale).transfer(connector.address, amountIn)
    await connector.connect(whale).swap(WETH, USDC, amountIn, 0, MAX_UINT256, '0x')
    const currentBalance = await usdc.balanceOf(whale.address)
    expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
  })

  it('can swap with Balancer V2 Batch', async () => {
    await connector.setBalancerV2BatchPath(WETH, DAI, USDC, BALANCER_POOL_DAI_WETH_ID, BALANCER_POOL_USDC_DAI_ID)

    const previousBalance = await usdc.balanceOf(whale.address)
    await weth.connect(whale).transfer(connector.address, amountIn)
    await connector.connect(whale).swap(WETH, USDC, amountIn, 0, MAX_UINT256, '0x')
    const currentBalance = await usdc.balanceOf(whale.address)
    expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
  })
})
