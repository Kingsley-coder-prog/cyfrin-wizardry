"use client";

import {QueryClient, QueryClientProvider} from "@tanstack/react-query";
import { type ReactNode, useState, useEffect } from "react";
import config from "@/rainbowKitConfig";
import { WagmiProvider }  from "wagmi";
import {RainbowKitProvider} from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import Header from "@/components/Header";

export function Providers(props: {children: ReactNode}) {
    const [queryClient] = useState(()=> new QueryClient());
    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider>
                    <Header />
                    {props.children}
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    )
}