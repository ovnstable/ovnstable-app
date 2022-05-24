const dotenv = require("dotenv");
dotenv.config({path:__dirname+ '/../../../.env'});

let FANTOM = {
    usdc: "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75",
    amUsdc: "0x625E7708f30cA75bfd92586e17077590C60eb4cD",
    crv2Pool: "0x27E611FD27b276ACbd5Ffd632E5eAEBEC9761E40",
    crv2PoolToken: "0x27E611FD27b276ACbd5Ffd632E5eAEBEC9761E40",
    crv2PoolGauge: "0x8866414733F22295b7563f9C5299715D2D76CAf4",
    crvGeist: "0x0fa949783947Bf6c1b171DB13AEACBB488845B3f",
    crvGeistToken: "0xD02a30d33153877BC20e5721ee53DeDEE0422B2F",
    crvGeistGauge: "0xd4F94D0aaa640BBb72b5EEc2D85F6D114D81a88E",
    geist: "0xd8321AA83Fb0a4ECd6348D4577431310A6E0814d",
    crv: "0x1E4F97b9f9F913c46F1632781732927B9019C68b",
    wFtm: "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83",
    tarotRouter: "0x283e62CFe14b352dB8e30A9575481DCbf589Ad98",
    bTarotSpirit: "0x710675A9c8509D3dF254792C548555D3D0a69494",
    bTarotSpooky: "0xb7FA3710A69487F37ae91D74Be55578d1353f9df",
    tUsdc: "0x68d211Bc1e66814575d89bBE4F352B4cdbDACDFb",
    tarotSupplyVaultRouter: "0x3E9F34309B2f046F4f43c0376EFE2fdC27a10251",
    dei: "0xde12c7959e1a72bbe8a5f7a1dc8f8eef9ab011b3",
    bptDeiUsdc: "0x8B858Eaf095A7337dE6f9bC212993338773cA34e",
    asUsdc: "0xb5E4D17FFD9D0DCE46D290750dad5F9437B5A16B",
    bptUsdcAsUSDC: "0x8Bb1839393359895836688165f7c5878f8C81C5e",
    beets: "0xF24Bcf4d1e507740041C9cFd2DddB29585aDCe1e",
    deus: "0xDE5ed76E7c05eC5e4572CfC88d1ACEA165109E44",
    aaveProvider: "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb",
    spookySwapRouter: "0xF491e7B69E4244ad4002BC14e878a34207E38c29",
    beethovenxVault: "0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce",
    beethovenxMasterChef: "0x8166994d9ebBe5829EC86Bd81258149B87faCfd3",
    creamTokenAndDelegator: "0x328A7b4d538A2b3942653a9983fdA3C12c571141",
    screamTokenDelegator: "0xE45Ac34E528907d0A0239ab5Db507688070B20bf",
    screamUnitroller: "0x260E596DAbE3AFc463e75B6CC05d8c46aCAcFB09",
    scream: "0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475",
    spookySwapLPMaiUsdc: "0x4dE9f0ED95de2461B6dB1660f908348c42893b1A",
    spookySwapLPTusdUsdc: "0x12692B3bf8dd9Aa1d2E721d1a79efD0C244d7d96",
    spookySwapMasterChef: "0x2b2929E785374c651a81A63878Ab22742656DcDd",
    mai: "0xfB98B335551a418cD0737375a2ea0ded62Ea213b",
    tusd: "0x9879aBDea01a879644185341F7aF7d8343556B7a",
    boo: "0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE",
    wigo: "0xE992bEAb6659BFF447893641A378FbbF031C5bD6",
    dai: "0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E",
    fusdt: "0x049d68029688eAbF473097a2fC38ef61633A3C7A",
    WigoRouter: "0x5023882f4D1EC10544FCB2066abE9C1645E95AA0",
    WigoLPUsdcDai: "0xFDc67A84C3Aa2430c024B7d35B3c09872791d722",
    WigoLPUsdcFUsdt: "0x219eF2d8DaD28a72dA297E79ed6a990F65307a4C",
    WigoMasterFarmer: "0xA1a938855735C0651A6CfE2E93a32A28A236d0E9",
}

let POLYGON = {
    idleUsdc: "0x1ee6470cd75d5686d0b2b90c0305fa46fb0c89a1",
    usdc: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
    usdt: "0xc2132d05d31c914a87c6611c10748aeb04b58e8f",
    amUsdc: "0x625E7708f30cA75bfd92586e17077590C60eb4cD",
    am3CRV: "0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171",
    am3CRVgauge: "0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c",
    wMatic: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    crv: "0x172370d5Cd63279eFa6d502DAB29171933a610AF",
    mUsd: "0xE840B73E5287865EEc17d250bFb1536704B43B21",
    imUsd: "0x5290Ad3d83476CA6A2b178Cd9727eE1EF72432af",
    vimUsd: "0x32aBa856Dc5fFd5A56Bcd182b13380e5C855aa29",
    mta: "0xf501dd45a1198c2e1b5aef5314a68b9006d842e0",
    bpspTUsd: "0x0d34e5dD4D8f043557145598E4e2dC286B35FD4f",
    tUsd: "0x2e1ad108ff1d8c782fcbbb89aad783ac49586756",
    bal: "0x9a71012b13ca4d3d0cdc72a177df3ef03b0e76a3",
    izi: "0x60d01ec2d5e98ac51c8b4cf84dfcce98d527c747",
    yin: "0x794Baab6b878467F93EF17e2f2851ce04E3E34C8",
    weth: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
    dodo: "0xe4Bf2864ebeC7B7fDf6Eeca9BaCAe7cDfDAffe78",
    quickSwapRouter: "0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff",
    crvAavePool: "0x445FE580eF8d70FF569aB36e80c647af338db351",
    aaveProvider: "0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb",
    balancerVault: "0xBA12222222228d8Ba445958a75a0704d566BF2C8",
    merkleOrchard: "0x0F3e0c4218b7b0108a3643cFe9D3ec0d4F57c54e",
    balancerPoolIdUsdcTusdDaiUsdt: "0x0d34e5dd4d8f043557145598e4e2dc286b35fd4f000000000000000000000068",
    balancerPoolIdWmaticUsdcWethBal: "0x0297e37f1873d2dab4487aa67cd56b58e2f27875000100000000000000000002",
    balancerPoolIdWmaticMtaWeth: "0x614b5038611729ed49e0ded154d8a5d3af9d1d9e00010000000000000000001d",
    uniswapV3PositionManager: "0xc36442b4a4522e871399cd717abdd847ab11fe88",
    uniswapV3Pool: "0x3F5228d0e7D75467366be7De2c31D0d098bA2C23",
    uniswapV3Router: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
    izumiBoost: "0x01cc44fc1246d17681b325926865cdb6242277a5",
    uniswapNftToken: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
    aaveCurve: "0x445fe580ef8d70ff569ab36e80c647af338db351",
    impermaxRouter: "0x7c79a1c2152665273ebd50e9e88d92a887a83ba0",
    imxbTokenQsUsdcUsdt: "0xEaB52C4eFBbB54505EB3FC804A29Dcf263668965",
    imxbTokenQsMaticUsdt: "0xed618c29abc8fa6ee05b33051b3cdb4a1efb7924",
    imxbTokenQsWethUsdt: "0x64ce3e18c091468acf30bd861692a74ce48a0c7c",
    imxbTokenQsMaiUsdt: "0x0065A0effbb58e4BeB2f3A40fDcA740F85585213",
    usdcLPToken: "0x2C5CA709d9593F6Fd694D84971c55fB3032B87AB",
    usdtLPToken: "0xB0B417A00E1831DeF11b242711C3d251856AADe3",
    dodoV1UsdcUsdtPool: "0x813FddecCD0401c4Fa73B092b074802440544E52",
    dodoV2DodoUsdtPool: "0x581c7DB44F2616781C86C331d31c1F09db87A746",
    dodoMine: "0xB14dA65459DB957BCEec86a79086036dEa6fc3AD",
    dodoV1Helper: "0xDfaf9584F5d229A9DBE5978523317820A8897C5A",
    dodoProxy: "0xa222e6a71D1A1Dd5F279805fbe38d5329C1d0e70",
    dodoApprove: "0x6D310348d5c12009854DFCf72e0DF9027e8cb4f4",
    tetu: "0x255707B70BF90aa112006E1b07B9AeA6De021424",
    arrakisRouter: "0xbc91a120ccd8f80b819eaf32f0996dac3fa76a6c",
    oracleChainlinkUsdc: "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7",
    oracleChainlinkUsdt: "0x0A6513e40db6EB1b165753AD52E80663aeA50545",
}

let DEFAULT = POLYGON;

setDefault(process.env.ETH_NETWORK);

function setDefault(network) {
    console.log(`Assets: [${network}]`)

    switch (network) {
        case 'FANTOM':
            DEFAULT = FANTOM;
            break
        case 'POLYGON':
            DEFAULT = POLYGON;
            break
        default:
            throw new Error('Unknown network')
    }
}

module.exports = {
    POLYGON: POLYGON,
    FANTOM: FANTOM,
    DEFAULT: DEFAULT,
    setDefault: setDefault
}
