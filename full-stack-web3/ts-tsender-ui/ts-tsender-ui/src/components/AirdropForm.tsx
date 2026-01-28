"use client"

import InputField from "@/components/ui/InputField"
import {useState} from "react"
import { chainsToTSender, tsenderAbi, erc20Abi} from "@/constants"
import {useChainId, useConfig, useConnection} from 'wagmi'
import { readContract } from "@wagmi/core"

export default function AirdropForm() {
    const [tokenAddress, setTokenAddress] = useState("")
    const [recipients, setRecipients] = useState("")
    const [amounts, setAmounts] = useState("")
    const chainId = useChainId()
    const config = useConfig()
    const account = useConnection()


    async function getApprovedAmount(tSenderAddress: string | null): Promise<number> {
        if (!tSenderAddress) {
            alert("No address found, please use a supported chain")
            return 0
        }
        const response = await readContract(config, {
            abi: erc20Abi,
            address: tokenAddress as `0x${string}`,
            functionName: "allowance",
            args: [account.address, tSenderAddress as `0x${string}`]
        })
        return response as number
    }

    async function handleSubmit() {
        const tSenderAddress = chainsToTSender[chainId]["tsender"]
        const approvedAmount = await getApprovedAmount(tSenderAddress)
        console.log(approvedAmount)
    }

    return (
        <div>
            <InputField label="Token Address" placeholder="0x" value={tokenAddress} onChange={e => setTokenAddress(e.target.value)} />

            <InputField label="Recipients" placeholder="0x1234321, 0x12345432" value={recipients} onChange={e => setRecipients(e.target.value)} large={true} />

            <InputField label="Amount" placeholder="100, 200, 300...." value={amounts} onChange={e => setAmounts(e.target.value)} large={true} />

            <button onClick={handleSubmit} className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg shadow-sm transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed">
                Send tokens
            </button>
        </div>
    )
}