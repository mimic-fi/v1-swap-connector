import { assertEvent, deploy, fp, impersonate, instanceAt, MAX_UINT256 } from '@mimic-fi/v1-helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { BigNumber, Contract } from 'ethers'
import { ethers } from 'hardhat'

/* eslint-disable no-secrets/no-secrets */

const USDC = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'
const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
const WBTC = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'
const WHALE = '0xf584f8728b874a6a5c7a8d4d387c9aae9172d621'

const UNISWAP_V2_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
const UNISWAP_V3_ROUTER = '0xE592427A0AEce92De3Edee1F18E0157C05861564'
const BALANCER_V2_VAULT = '0xBA12222222228d8Ba445958a75a0704d566BF2C8'

const UNISWAP_V3_FEE = 3000
const PRICE_ONE_ORACLE = '0x1111111111111111111111111111111111111111'
const CHAINLINK_ORACLE_USDC_ETH = '0x986b5E1e1755e3C2440e960477f25201B0a8bbD4'
const CHAINLINK_ORACLE_WBTC_ETH = '0xdeb288F737066589598e9214E782fa5A8eD689e8'
const BALANCER_POOL_WETH_USDC_ID = '0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019'
const BALANCER_POOL_WETH_WBTC_ID = '0xa6f548df93de924d73be7d25dc02554c6bd66db500020000000000000000000e'

describe('SwapConnector', () => {
  let connector: Contract, priceOracle: Contract
  let weth: Contract, wbtc: Contract, usdc: Contract, whale: SignerWithAddress

  const slippage = fp(0.025)

  const getPath = (tokenA: string, tokenB: string): string => {
    return ethers.utils.solidityKeccak256(['address', 'address'], [tokenA, tokenB])
  }

  const getExpectedMinAmountOut = async (tokenIn: string, tokenOut: string, amountIn: BigNumber) => {
    const price = await priceOracle.getTokenPrice(tokenOut, tokenIn)
    const expectedAmountOut = price.mul(amountIn).div(fp(1))
    return expectedAmountOut.sub(expectedAmountOut.mul(slippage).div(fp(1)))
  }

  before('create price oracle', async () => {
    const priceOracleTokens: string[] = [USDC, WBTC, WETH]
    const priceOracleFeeds: string[] = [CHAINLINK_ORACLE_USDC_ETH, CHAINLINK_ORACLE_WBTC_ETH, PRICE_ONE_ORACLE]
    priceOracle = await deploy(
      '@mimic-fi/v1-chainlink-price-oracle/artifacts/contracts/ChainLinkPriceOracle.sol/ChainLinkPriceOracle',
      [priceOracleTokens, priceOracleFeeds]
    )
  })

  before('create swap connector', async () => {
    const args = [priceOracle.address, UNISWAP_V3_ROUTER, UNISWAP_V2_ROUTER, BALANCER_V2_VAULT]
    connector = await deploy('SwapConnector', args)
  })

  before('load tokens and accounts', async () => {
    weth = await instanceAt('IERC20', WETH)
    wbtc = await instanceAt('IERC20', WBTC)
    usdc = await instanceAt('IERC20', USDC)
    whale = await impersonate(WHALE, fp(100))
  })

  const itSingleSwapsCorrectly = () => {
    it('swaps correctly USDC-WETH', async () => {
      const amountIn = fp(10e3).div(1e12) // USDC 6 decimals
      const previousBalance = await weth.balanceOf(WHALE)
      await usdc.connect(whale).transfer(connector.address, amountIn)

      await connector.connect(whale).swap(USDC, WETH, amountIn, 0, MAX_UINT256, '0x')

      const currentBalance = await weth.balanceOf(WHALE)
      const expectedMinAmountOut = await getExpectedMinAmountOut(USDC, WETH, amountIn)
      expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
    })

    it('swaps correctly WETH-USDC', async () => {
      const amountIn = fp(50)
      const previousBalance = await usdc.balanceOf(WHALE)
      await weth.connect(whale).transfer(connector.address, amountIn)

      await connector.connect(whale).swap(WETH, USDC, amountIn, 0, MAX_UINT256, '0x')

      const currentBalance = await usdc.balanceOf(WHALE)
      const expectedMinAmountOut = await getExpectedMinAmountOut(WETH, USDC, amountIn)
      expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
    })
  }

  const itBatchSwapsCorrectly = () => {
    it('swaps correctly USDC-WBTC', async () => {
      const amountIn = fp(10e3).div(1e12) // USDC 6 decimals
      const previousBalance = await wbtc.balanceOf(WHALE)
      await usdc.connect(whale).transfer(connector.address, amountIn)

      await connector.connect(whale).swap(USDC, WBTC, amountIn, 0, MAX_UINT256, '0x')

      const currentBalance = await wbtc.balanceOf(WHALE)
      const expectedMinAmountOut = await getExpectedMinAmountOut(USDC, WBTC, amountIn)
      expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
    })

    it('swaps correctly WTBC-USDC', async () => {
      const amountIn = fp(1).div(1e10) // WBTC 8 decimals
      const previousBalance = await usdc.balanceOf(WHALE)
      await wbtc.connect(whale).transfer(connector.address, amountIn)

      await connector.connect(whale).swap(WBTC, USDC, amountIn, 0, MAX_UINT256, '0x')

      const currentBalance = await usdc.balanceOf(WHALE)
      const expectedMinAmountOut = await getExpectedMinAmountOut(WBTC, USDC, amountIn)
      expect(currentBalance.sub(previousBalance)).to.be.at.least(expectedMinAmountOut)
    })
  }

  context('Uniswap V2', () => {
    context('single swap', () => {
      before('set dex', async () => {
        const tokens = [WETH, USDC]

        const tx = await connector.setUniswapV2Path(tokens, true)
        await assertEvent(tx, 'PathDexSet', { path: getPath(WETH, USDC), tokenA: WETH, tokenB: USDC, dex: 0 })
        await assertEvent(tx, 'PathDexSet', { path: getPath(USDC, WETH), tokenA: USDC, tokenB: WETH, dex: 0 })
      })

      it('stores the expected config', async () => {
        const result = await connector.getUniswapV2Path(USDC, WETH)
        expect(result.hopTokens).to.be.empty
      })

      itSingleSwapsCorrectly()
    })

    context('batch swap', () => {
      before('set dex', async () => {
        const tokens = [WBTC, WETH, USDC]

        const tx = await connector.setUniswapV2Path(tokens, true)
        await assertEvent(tx, 'PathDexSet', { path: getPath(WBTC, USDC), tokenA: WBTC, tokenB: USDC, dex: 0 })
        await assertEvent(tx, 'PathDexSet', { path: getPath(USDC, WBTC), tokenA: USDC, tokenB: WBTC, dex: 0 })
      })

      it('stores the expected config', async () => {
        const result = await connector.getUniswapV2Path(USDC, WBTC)
        expect(result.hopTokens.length).to.be.equal(1)
        expect(result.hopTokens[0]).to.be.equal(WETH)
      })

      itBatchSwapsCorrectly()
    })
  })

  context('Uniswap V3', () => {
    context('single swap', () => {
      before('set dex', async () => {
        const tokens = [WETH, USDC]
        const fees = [UNISWAP_V3_FEE]

        const tx = await connector.setUniswapV3Path(tokens, fees, true)
        await assertEvent(tx, 'PathDexSet', { path: getPath(WETH, USDC), tokenA: WETH, tokenB: USDC, dex: 1 })
        await assertEvent(tx, 'PathDexSet', { path: getPath(USDC, WETH), tokenA: USDC, tokenB: WETH, dex: 1 })
      })

      it('stores the expected config', async () => {
        const result = await connector.getUniswapV3Path(USDC, WETH)
        expect(result.fee).to.be.equal(UNISWAP_V3_FEE)
        expect(result.poolsPath).to.be.equal('0x')
      })

      itSingleSwapsCorrectly()
    })

    context('batch swap', () => {
      before('set dex', async () => {
        const tokens = [WBTC, WETH, USDC]
        const fees = [UNISWAP_V3_FEE, UNISWAP_V3_FEE]

        const tx = await connector.setUniswapV3Path(tokens, fees, true)
        await assertEvent(tx, 'PathDexSet', { path: getPath(WBTC, USDC), tokenA: WBTC, tokenB: USDC, dex: 1 })
        await assertEvent(tx, 'PathDexSet', { path: getPath(USDC, WBTC), tokenA: USDC, tokenB: WBTC, dex: 1 })
      })

      function encodePath(tokens: string[], fees: number[]): string {
        let encoded = '0x'
        for (let i = 0; i < fees.length; i++) {
          encoded += tokens[i].slice(2)
          encoded += fees[i].toString(16).padStart(2 * 3, '0')
        }
        encoded += tokens[tokens.length - 1].slice(2)
        return encoded.toLowerCase()
      }

      it('stores the expected config', async () => {
        const result = await connector.getUniswapV3Path(USDC, WBTC)
        expect(result.fee).to.be.equal(0)

        const expectedPath = encodePath([USDC, WETH, WBTC], [UNISWAP_V3_FEE, UNISWAP_V3_FEE])
        expect(result.poolsPath).to.be.equal(expectedPath)
      })

      itBatchSwapsCorrectly()
    })
  })

  context('Balancer V2', () => {
    context('single swap', () => {
      before('set dex', async () => {
        const tokens = [WETH, USDC]
        const poolIds = [BALANCER_POOL_WETH_USDC_ID]

        const tx = await connector.setBalancerV2Path(tokens, poolIds, true)
        await assertEvent(tx, 'PathDexSet', { path: getPath(WETH, USDC), tokenA: WETH, tokenB: USDC, dex: 2 })
        await assertEvent(tx, 'PathDexSet', { path: getPath(USDC, WETH), tokenA: USDC, tokenB: WETH, dex: 2 })
      })

      it('stores the expected config', async () => {
        const result = await connector.getBalancerV2Path(USDC, WETH)
        expect(result.poolId).to.be.equal(BALANCER_POOL_WETH_USDC_ID)
        expect(result.hopTokens).to.be.empty
        expect(result.hopPoolIds).to.be.empty
      })

      itSingleSwapsCorrectly()
    })

    context('batch swap', () => {
      before('set dex', async () => {
        const tokens = [WBTC, WETH, USDC]
        const poolIds = [BALANCER_POOL_WETH_WBTC_ID, BALANCER_POOL_WETH_USDC_ID]

        const tx = await connector.setBalancerV2Path(tokens, poolIds, true)
        await assertEvent(tx, 'PathDexSet', { path: getPath(WBTC, USDC), tokenA: WBTC, tokenB: USDC, dex: 2 })
        await assertEvent(tx, 'PathDexSet', { path: getPath(USDC, WBTC), tokenA: USDC, tokenB: WBTC, dex: 2 })
      })

      it('stores the expected config', async () => {
        const result = await connector.getBalancerV2Path(USDC, WBTC)
        expect(result.poolId).to.be.equal(BALANCER_POOL_WETH_USDC_ID)
        expect(result.hopTokens.length).to.be.equal(1)
        expect(result.hopTokens[0]).to.be.equal(WETH)
        expect(result.hopPoolIds.length).to.be.equal(1)
        expect(result.hopPoolIds[0]).to.be.equal(BALANCER_POOL_WETH_WBTC_ID)
      })

      itBatchSwapsCorrectly()
    })
  })
})
