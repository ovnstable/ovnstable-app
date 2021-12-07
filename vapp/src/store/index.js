import Vue from 'vue';
import Vuex from 'vuex';
import profile from "./modules/profile";
import showTransactions from './modules/show-transaction';
import transaction from './modules/transaction'
import gasPrice from './modules/gas-price';
import web3 from "./modules/web3";
import accountProfile from './modules/account-profile';
import governance from './modules/governance';

import createPersistedState from "vuex-persistedstate";

Vue.use(Vuex);

export default new Vuex.Store({
    modules: {
        profile,
        gasPrice,
        showTransactions,
        transaction,
        governance,
        web3,
        accountProfile
    },
    plugins: [createPersistedState({paths: ['transaction']})]
});
