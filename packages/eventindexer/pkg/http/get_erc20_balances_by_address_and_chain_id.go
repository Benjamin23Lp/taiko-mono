package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetERC20BalancesByAddressAndChainID
//
//	 returns erc20 balances by address and chain ID
//
//			@Summary		Get erc20 balances by address and chain ID
//			@ID			   	get-erc20-balances-by-address-and-chain-id
//		    @Param			address	query		string		true	"address to query"
//		    @Param			chainID	query		string		true	"chainID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/erc20sByAddress [get]
func (srv *Server) GetERC20BalancesByAddressAndChainID(c echo.Context) error {
	page, err := srv.erc20BalanceRepo.FindByAddress(
		c.Request().Context(),
		c.Request(),
		c.QueryParam("address"),
		c.QueryParam("chainID"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, page)
}
