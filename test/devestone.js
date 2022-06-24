const DevestOne = artifacts.require("DevestOne");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");

contract('DevestOne', (accounts) => {

    it('should put 1000000 Token in the first account', async () => {
        const ERC20TokenInstance = await ERC20.deployed();
        const balance = await ERC20TokenInstance.balanceOf.call(accounts[0]);

        const balanceAccount = await web3.eth.getBalance(accounts[0]);

        assert.isTrue(balance.valueOf() > 0, "To less token");
        assert.isTrue(Number(balanceAccount) > 0)
    });

    it('should transfer some ETH Token to all traders', async () => {
        const erc20Token = await ERC20.deployed();

        // Setup account.
        const account = accounts[0];

        // Make transaction from first account to second.
        for (let i = 2; i < 10; i++) {
            const amount = 40000000000;
            await erc20Token.transfer(accounts[i], amount, { from: account });
        }

        // Get balances of first and second account after the transactions.
        const accountOneEndingBalance = (await erc20Token.balanceOf.call(account)).toNumber();

        // send back
        assert.equal(accountOneEndingBalance, 680000000000, "Failed to transfer funds");
    });

    it('should Setup Tangible', async () => {
        const devestOne = await DevestOne.deployed();

        // check if variables set
        const name = await devestOne.name.call();
        assert(name, "Example", "Invalid name on TST");

        await devestOne.initialize(3000000000, 10, true, { from: accounts[0] });
        await devestOne.setTangible(accounts[1], { from: accounts[0] });

        const pricePerUnit = (await devestOne.price.call()).toNumber();
        assert.equal(pricePerUnit, 3000000000 / 100, "Invalid price on initialized tangible");
    })

    it('Submit Bid Orders', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        // submit bid
        const pricePerShare = 30000000;
        const amountOfShares = 50;
        const totalPrice = pricePerShare * amountOfShares;
        const escrow = totalPrice + ((totalPrice) * 0.1); // totalPrice + tax (10%)

        await erc20Token.approve(devestOne.address, escrow, { from: accounts[2] });
        await devestOne.bid(pricePerShare, 50, { from: accounts[2] });

        // tangible funds should increase
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, escrow, "Invalid funds after bid");

        const orders = await devestOne.getOrders.call();
        assert.equal(orders.length, 1, "Order not stored");
        assert.equal(orders[0].price, pricePerShare, "Order has invalid price");
    });

    it('Accept Bid Orders (A)', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        // --- before
        const fundsOwnerBefore = (await erc20Token.balanceOf.call(accounts[0])).toNumber();

        // fetch orders
        const orders = await devestOne.getOrders.call();
        await devestOne.accept(orders[0].from, 50, { from: accounts[0], value: 100000000 });

        // check if tax was paid
        const taxReceiver = (await erc20Token.balanceOf(accounts[1])).toNumber();
        assert.equal(taxReceiver, 150000000, "Invalid funds on player after buy order");

        // check if owner got funds back
        const fundsOwnerAfter = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(fundsOwnerAfter, fundsOwnerBefore + (150000000 * 10), "Seller (owner) received invalid amount for swap");

        // no more funds on tangible ( all spend )
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, 0, "Invalid funds on tangible after accept");

        const price = (await devestOne.price.all()).toNumber();
        assert.equal(price, 30000000, "Invalid price, in PreSale phase");

        const share = (await devestOne.getShares.call(accounts[2])).toNumber();
        assert.equal(share, 50, "Invalid share of staker");
    })

    it('Check if orders been closed', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        const offers = await devestOne.getOrders.call();
        assert.equal(offers.length, 0, "Buy order not closed");

        const sharedholders = await devestOne.getShareholders.call();
        assert.equal(sharedholders.length, 2, "New shareholder not included in shareholders");
    });

    it("Create ask order", async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        await devestOne.ask(40000000, 25, { from: accounts[0] });

        const offers = await devestOne.getOrders.call();
        assert.equal(offers[0].from, accounts[0], "Invalid ask order created");
    })

    it("Accept ask order", async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        // --- before
        const fundsOwnerBefore = (await erc20Token.balanceOf.call(accounts[0])).toNumber();

        // fetch orders
        const pricePerShare = 40000000;
        const amountOfShares = 2;
        const totalPrice = pricePerShare * amountOfShares;
        const escrow = totalPrice + ((totalPrice) * 0.1); // totalPrice + tax (10%)

        await erc20Token.approve(devestOne.address, escrow, { from: accounts[3] });
        const orders = await devestOne.getOrders.call();
        await devestOne.accept(orders[0].from, 2, { from: accounts[3], value: 100000000 });

        // check if tax was paid
        const taxReceiver = (await erc20Token.balanceOf(accounts[1])).toNumber();
        assert.equal(taxReceiver, 158000000, "Invalid funds on player after buy order");

        // check if owner got funds back
        const fundsOwnerAfter = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(fundsOwnerAfter, fundsOwnerBefore + (40000000 * 2), "Seller (owner) received invalid amount for swap");

        // no more funds on tangible ( all spend )
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, 0, "Invalid funds on tangible after accept");

        const price = (await devestOne.price.call()).toNumber();
        assert.equal(price, 40000000, "Invalid price, in PreSale phase");

        const shareOwner = (await devestOne.getShares.call(accounts[0])).toNumber();
        const share3 = (await devestOne.getShares.call(accounts[3])).toNumber();
        assert.equal(shareOwner, 48, "Invalid share of staker");
        assert.equal(share3, 2, "Invalid share of staker");
    });

    it('Add more buy orders', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        const price = (await devestOne.price.call()).toNumber();

        // submit bid
        await createBid(20, price, accounts[4]);
        await createBid(10, price * 1.5, accounts[5]);
        await createBid(20, price * 2, accounts[6]);
        await createBid(20, price * 0.5, accounts[7]);

        let totalEscrow = 20 * price + (10 * price * 1.5) + (20 * price * 2) + (20 * price * 0.5);
        totalEscrow += (totalEscrow * 10) / 100;

        // tangible funds should increase
        const fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangible, totalEscrow, "Invalid funds submitting buy orders");

        const orders = await devestOne.getOrders.call();
        assert.equal(orders.length, 5, "Order not stored");
        assert.equal(orders[3].price, 80000000, "Order has invalid price");
    })

    it('Accept bids', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        let fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        let fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        let earningOnwer = 0;

        // fetch offers
        const offers = await devestOne.getOrders.call();

        // --- accept #1

        await devestOne.accept(offers[1].from, 20, { from: accounts[0], value: 10000000 });
        fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(earningOnwer, 800000000, "Invalid tax paid to player");

        // --- accept #2

        await devestOne.accept(offers[2].from, 10, { from: accounts[0], value: 10000000 });
        fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(earningOnwer, 1400000000, "Invalid tax paid to player");

        // --- accept #3

        await devestOne.accept(offers[3].from, 10, { from: accounts[0], value: 10000000 });

        fundsTangible = (await erc20Token.balanceOf.call(accounts[1])).toNumber();
        earningOnwer += ((await erc20Token.balanceOf.call(accounts[0])).toNumber() - fundsOwner);
        fundsOwner = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        assert.equal(earningOnwer, 2200000000, "Invalid funds on player after bid");

        // --- leftover escrow

        fundsTangible = (await erc20Token.balanceOf.call(accounts[0])).toNumber();
        const total = 683780000000;
        assert.equal(fundsTangible, total, "Invalid funds on tangible after accept");

        // --- all shareholders
        const shareholders = await devestOne.getShareholders.call();
        assert.equal(shareholders[0], accounts[0], "Invalid shares");
        const sharesOnwner = 48 - 20 - 10 - 10;
        assert.equal((await devestOne.getShares.call(accounts[0])).toNumber(), sharesOnwner, "Invalid shares");

        assert.equal(shareholders[1], accounts[2], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[2])).toNumber(), 50, "Invalid shares");

        assert.equal(shareholders[2], accounts[3], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[3])).toNumber(), 2, "Invalid shares");

        assert.equal(shareholders[3], accounts[4], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[4])).toNumber(), 20, "Invalid shares");

        assert.equal(shareholders[4], accounts[5], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[5])).toNumber(), 10, "Invalid shares");

        assert.equal(shareholders[5], accounts[6], "Invalid shares");
        assert.equal((await devestOne.getShares.call(accounts[6])).toNumber(), 10, "Invalid shares");
    });

    it('Cancel offer, and get escrow back', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        let orders = await devestOne.getOrders.call();

        let fundsTangible = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        let fundsOrder6Before = (await erc20Token.balanceOf.call(accounts[6])).toNumber();
        let fundsOrder7Before = (await erc20Token.balanceOf.call(accounts[7])).toNumber();

        // has 10 amount left in offer
        try {
            await devestOne.cancel({from: accounts[5]});
        } catch (ex){
            assert.equal(ex.message, "Returned error: VM Exception while processing transaction: revert No open bid -- Reason given: No open bid.");
        }
        await devestOne.cancel({ from: accounts[0] });
        await devestOne.cancel({ from: accounts[6] });
        await devestOne.cancel({ from: accounts[7] });

        // 1200000000
        // check offers
        orders = await devestOne.getOrders.call();
        assert.equal(orders.length, 0, "Offers was not cancelled");

        let fundsTangibleAfter = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangibleAfter, 0, "Escrow not returned");

        let fundsOrder6After = (await erc20Token.balanceOf.call(accounts[6])).toNumber();
        // for account 6
        // price was 400000 * 20, 10 been soled
        const escrow6 = (40000000 * 2 * 10) * 1.1;
        assert.equal(fundsOrder6Before + escrow6, fundsOrder6After, "Escrow not returned");

        let fundsOrder7After = (await erc20Token.balanceOf.call(accounts[7])).toNumber();
        // for acocunt 7
        // price was 4000000 * 0.5
        const escrow7 = (40000000 * 0.5 * 20) * 1.1;
        assert.equal(fundsOrder7Before + escrow7, fundsOrder7After, "Escrow not returned");
    });

    it('Pay', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        // collect current funds of shareholders before dividends are paid
        const shareholders = await devestOne.getShareholders.call();
        const shareHoldersFunds = [];
        for(let shareholder of shareholders){
            shareHoldersFunds.push({
                address: shareholder,
                balance: (await erc20Token.balanceOf.call(shareholder)).toNumber(),
                shares: (await devestOne.getShares.call(shareholder)).toNumber(),
            });
        }

        // disburse
        await erc20Token.approve(devestOne.address, 200000000, { from: accounts[1] })
        await devestOne.pay(200000000, { from: accounts[1] });

        // TST should be empty
        const fundsTangibleAfter = (await erc20Token.balanceOf.call(devestOne.address)).toNumber();
        assert.equal(fundsTangibleAfter, 0, "Disburse failed TST Balance invalid");

        // check dividends
        const split = 200000000 * 0.9; // remove tax
        for(let shareholder of shareHoldersFunds){
            const after = (await erc20Token.balanceOf.call(shareholder.address)).toNumber();
            const d = (shareholder.shares *  split) / 100;
            assert.equal(shareholder.balance + d, after, "Invalid dividends disbursed");
        }
    })

    it('Switch tangible', async () => {
        const devestOne = await DevestOne.deployed();

        // call terminate until 50% reached
        await devestOne.setTangible(accounts[2], { from: accounts[0] });
        await devestOne.setTangible(accounts[2], { from: accounts[3] });
        await devestOne.setTangible(accounts[2], { from: accounts[4] });

        let address = await devestOne.tangibleAddress.call();
        assert.equal(address, accounts[1], "Contract should still have same tangible");

        await devestOne.setTangible(accounts[2], { from: accounts[2] });
        address = await devestOne.tangibleAddress.call();
        assert.equal(address, accounts[2], "Tangible after vote not updated");
    });

    it('Terminate Share', async () => {
        const erc20Token = await ERC20.deployed();
        const devestOne = await DevestOne.deployed();

        // call terminate until 50% reached
        await devestOne.terminate({ from: accounts[0] });
        await devestOne.terminate({ from: accounts[3] });
        await devestOne.terminate({ from: accounts[4] });

        let state = await devestOne.terminated.call();
        assert.equal(state, false, "Contract should not be terminated (to less votes)");

        await devestOne.terminate({ from: accounts[2] });
        state = await devestOne.terminated.call();
        assert.equal(state, true, "Contract should be terminated");
    });

});

const createBid = async (percent, price, address) => {
    const erc20Token = await ERC20.deployed();
    const devestOne = await DevestOne.deployed();

    // submit bid
    let escrow = price * percent;
    escrow = escrow + (escrow * 0.1)
    await erc20Token.approve(devestOne.address, escrow, { from: address });
    await devestOne.bid(price, percent, { from: address });
}
