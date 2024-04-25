import { waitForTransactionReceipt, writeContract } from '@wagmi/core'
import { decodeEventLog } from 'viem'

import getProof from '$lib/whitelist/getProof'
import { config } from '$wagmi-config'

import { taikoonTokenAbi, taikoonTokenAddress } from '../../generated/abi'
import { web3modal } from '../../lib/connect'
import type { IChainId } from '../../types'
import { canFreeMint } from './canFreeMint'
import { freeMintsLeft } from './mintsLeft'

export async function mint({
    freeMintCount,
    onTransaction,
}: {
    freeMintCount: number
    onTransaction: (tx: string) => void
}): Promise<number[]> {
    const { selectedNetworkId } = web3modal.getState()
    if (!selectedNetworkId) return []
    let tx: any
    const chainId = selectedNetworkId as IChainId

    const freeMintLeft = await freeMintsLeft()

    if (freeMintCount > freeMintLeft) {
        throw new Error('Not enough free mints left')
    }

    if (await canFreeMint()) {
        const proof = getProof()
        tx = await writeContract(config, {
            abi: taikoonTokenAbi,
            address: taikoonTokenAddress[chainId],
            functionName: 'mint',
            args: [proof, BigInt(freeMintLeft), BigInt(freeMintCount)],
            chainId,
        })

        onTransaction(tx)
    }

    let nounId: number = 0

    const receipt = await waitForTransactionReceipt(config, { hash: tx })

    const tokenIds: number[] = []

    receipt.logs.forEach((log: any) => {
        try {
            const decoded = decodeEventLog({
                abi: taikoonTokenAbi,
                data: log.data,
                topics: log.topics,
            })

            if (decoded.eventName === 'Transfer') {
                const args: {
                    to: string
                    tokenId: bigint
                } = decoded.args as any
                nounId = parseInt(args.tokenId.toString())
                tokenIds.push(nounId)
            }
        } catch (e) {
            //console.warn(e)
        }
    })
    return tokenIds
}
