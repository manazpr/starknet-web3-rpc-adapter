
%lang starknet

from starkware.starknet.common.syscalls import delegate_call, get_tx_info, get_contract_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from openzeppelin.upgrades.library import (
    Proxy_set_implementation,
    Proxy_implementation_address,
)

@contract_interface
namespace IAccountContract:
    func initializer(proxy_admin: felt, eth_address: felt, chain: felt):
    end
end

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(implementation_address: felt, eth_address: felt, chain: felt):
    Proxy_set_implementation(implementation_address)

    let (contract_address) = get_contract_address()

    IAccountContract.delegate_initializer(
        contract_address=implementation_address,
        proxy_admin=contract_address,
        eth_address=eth_address,
        chain=chain
    )

    return ()
end

@external
@raw_input
@raw_output
func __default__{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(
        selector: felt,
        calldata_size: felt,
        calldata: felt*
    ) -> (
        retdata_size: felt,
        retdata: felt*
    ):
    let (address) = Proxy_implementation_address.read()

    let (retdata_size: felt, retdata: felt*) = delegate_call(
        contract_address=address,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata
    )

    return (retdata_size=retdata_size, retdata=retdata)
end
