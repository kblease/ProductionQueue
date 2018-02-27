if string.sub(UI.GetAppVersion(),1,9) ~= "1.0.0.194" then
	-- ===========================================================================
	--	Production Panel / Purchase Panel
	-- ===========================================================================

	include( "ToolTipHelper" );
	include( "InstanceManager" );
	include( "TabSupport" );
	include( "Civ6Common" );
	include( "SupportFunctions" );
	include( "AdjacencyBonusSupport");
	include( "DragSupport" );
	include( "CitySupport" );

	-- ===========================================================================
	--	Constants
	-- ===========================================================================
	local RELOAD_CACHE_ID	:string = "ProductionPanel";
	local COLOR_LOW_OPACITY	:number = 0x3fffffff;
	local HEADER_Y			:number	= 41;
	local WINDOW_HEADER_Y	:number	= 150;
	local TOPBAR_Y			:number	= 28;
	local SEPARATOR_Y		:number	= 20;
	local BUTTON_Y			:number	= 48;
	local DISABLED_PADDING_Y:number	= 10;
	local TEXTURE_BASE				:string = "UnitFlagBase";
	local TEXTURE_CIVILIAN			:string = "UnitFlagCivilian";
	local TEXTURE_RELIGION			:string = "UnitFlagReligion";
	local TEXTURE_EMBARK			:string = "UnitFlagEmbark";
	local TEXTURE_FORTIFY			:string = "UnitFlagFortify";
	local TEXTURE_NAVAL				:string = "UnitFlagNaval";
	local TEXTURE_SUPPORT			:string = "UnitFlagSupport";
	local TEXTURE_TRADE				:string = "UnitFlagTrade";
	local BUILDING_IM_PREFIX		:string = "buildingListingIM_";
	local BUILDING_DRAWER_PREFIX	:string = "buildingDrawer_";
	local ICON_PREFIX				:string = "ICON_";
	local LISTMODE					:table	= {PRODUCTION = 1, PURCHASE_GOLD = 2, PURCHASE_FAITH=3};
	local EXTENDED_BUTTON_HEIGHT = 60;
	local DEFAULT_BUTTON_HEIGHT = 48;
	local PRODUCTION_TYPE :table = {
			BUILDING	= 1,
			UNIT		= 2,
			CORPS		= 3,
			ARMY		= 4,
			PLACED		= 5,
			PROJECT		= 6
	};

	-- ===========================================================================
	--	Members
	-- ===========================================================================

	local m_queueIM			= InstanceManager:new( "UnnestedList",  "Top", Controls.ProductionQueueList );
	local m_listIM			= InstanceManager:new( "NestedList",  "Top", Controls.ProductionList );
	local m_purchaseListIM	= InstanceManager:new( "NestedList",  "Top", Controls.PurchaseList );
	local m_purchaseFaithListIM	= InstanceManager:new( "NestedList",  "Top", Controls.PurchaseFaithList );

	local m_tabs;
	local m_productionTab;	-- Additional tracking of the tab control data so that we can select between graphical tabs and label tabs
	local m_purchaseTab;
	local m_faithTab;
	local m_maxProductionSize	:number	= 0;
	local m_maxPurchaseSize		:number	= 0;
	local m_isQueueMode			:boolean = false;
	local m_TypeNames			:table	= {};
	local m_kClickedInstance;
	local m_isCONTROLpressed	:boolean = false;
	local prodBuildingList;
	local prodWonderList;
	local prodUnitList;
	local prodDistrictList;
	local prodProjectList;
	local purchBuildingList;
	local purchGoldBuildingList;
	local purchFaithBuildingList;
	local purchUnitList;
	local purchGoldUnitList
	local purchFaithUnitList

	local showDisabled :boolean = true;
	local m_recommendedItems:table;

	-- Production Queue
	local nextDistrictSkipToFront = false;
	local showStandaloneQueueWindow = true;
	local _, screenHeight = UIManager:GetScreenSizeVal();
	local quickRefresh = true;
	local lastProductionCompletePerCity = {};
	local buildingPrereqs = {};
	local mutuallyExclusiveBuildings = {};
	local m_PrevDropTargetSlot = -1;
	local m_PrevDropTargetInstance = nil;

	------------------------------------------------------------------------------
	-- Collapsible List Handling
	------------------------------------------------------------------------------
	function OnCollapseTheList()
		m_kClickedInstance.List:SetHide(true);
		m_kClickedInstance.ListSlide:SetSizeY(0);
		m_kClickedInstance.ListAlpha:SetSizeY(0);
		Controls.PauseCollapseList:SetToBeginning();
		m_kClickedInstance.ListSlide:SetToBeginning();
		m_kClickedInstance.ListAlpha:SetToBeginning();
		Controls.ProductionList:CalculateSize();
		Controls.PurchaseList:CalculateSize();
		Controls.ProductionList:ReprocessAnchoring();
		Controls.PurchaseList:ReprocessAnchoring();
		Controls.ProductionListScroll:CalculateInternalSize();
		Controls.PurchaseListScroll:CalculateInternalSize();
	end

	-- ===========================================================================
	function OnCollapse(instance:table)
		m_kClickedInstance = instance;
		instance.ListSlide:Reverse();
		instance.ListAlpha:Reverse();
		instance.ListSlide:SetSpeed(15.0);
		instance.ListAlpha:SetSpeed(15.0);
		instance.ListSlide:Play();
		instance.ListAlpha:Play();
		instance.HeaderOn:SetHide(true);
		instance.Header:SetHide(false);
		Controls.PauseCollapseList:Play();	--By doing this we can delay collapsing the list until the "out" sequence has finished playing
	end

	-- ===========================================================================
	function OnExpand(instance:table)
		if(quickRefresh) then
			instance.ListSlide:SetSpeed(100);
			instance.ListAlpha:SetSpeed(100);
		else
			instance.ListSlide:SetSpeed(3.5);
			instance.ListAlpha:SetSpeed(4);
		end
		m_kClickedInstance = instance;
		instance.HeaderOn:SetHide(false);
		instance.Header:SetHide(true);
		instance.List:SetHide(false);
		instance.ListSlide:SetSizeY(instance.List:GetSizeY());
		instance.ListAlpha:SetSizeY(instance.List:GetSizeY());
		instance.ListSlide:SetToBeginning();
		instance.ListAlpha:SetToBeginning();
		instance.ListSlide:Play();
		instance.ListAlpha:Play();
		Controls.ProductionList:CalculateSize();
		Controls.PurchaseList:CalculateSize();
		Controls.ProductionList:ReprocessAnchoring();
		Controls.PurchaseList:ReprocessAnchoring();
		Controls.ProductionListScroll:CalculateInternalSize();
		Controls.PurchaseListScroll:CalculateInternalSize();
	end

	-- ===========================================================================
	function OnTabChangeProduction()
		Controls.MiniProductionTab:SetSelected(true);
		Controls.MiniPurchaseTab:SetSelected(false);
		Controls.MiniPurchaseFaithTab:SetSelected(false);
		Controls.PurchaseFaithMenu:SetHide(true);
	    Controls.PurchaseMenu:SetHide(true);
	    Controls.ChooseProductionMenu:SetHide(false);
	    if (Controls.SlideIn:IsStopped()) then
			UI.PlaySound("Production_Panel_ButtonClick");
	        UI.PlaySound("Production_Panel_Open");
	    end
	end

	-- ===========================================================================
	function OnTabChangePurchase()
		Controls.MiniProductionTab:SetSelected(false);
		Controls.MiniPurchaseTab:SetSelected(true);
		Controls.MiniPurchaseFaithTab:SetSelected(false);
		Controls.ChooseProductionMenu:SetHide(true);
		Controls.PurchaseFaithMenu:SetHide(true);
		Controls.PurchaseMenu:SetHide(false);
		UI.PlaySound("Production_Panel_ButtonClick");
	end

	-- ===========================================================================
	function OnTabChangePurchaseFaith()
		Controls.MiniProductionTab:SetSelected(false);
		Controls.MiniPurchaseTab:SetSelected(false);
		Controls.MiniPurchaseFaithTab:SetSelected(true);
		Controls.ChooseProductionMenu:SetHide(true);
		Controls.PurchaseMenu:SetHide(true);
		Controls.PurchaseFaithMenu:SetHide(false);
		UI.PlaySound("Production_Panel_ButtonClick");
	end

	-- ===========================================================================
	-- Placement/Selection
	-- ===========================================================================
	function BuildUnit(city, unitEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function BuildUnitCorps(city, unitEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		tParameters[CityOperationTypes.MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function BuildUnitArmy(city, unitEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		tParameters[CityOperationTypes.MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function BuildBuilding(city, buildingEntry)
		local building			:table		= GameInfo.Buildings[buildingEntry.Hash];
		local bNeedsPlacement	:boolean	= building.RequiresPlacement;

		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

		local pBuildQueue = city:GetBuildQueue();
		if (pBuildQueue:HasBeenPlaced(buildingEntry.Hash)) then
			bNeedsPlacement = false;
		end

		-- If it's a Wonder and the city already has the building then it doesn't need to be replaced.
		if (bNeedsPlacement) then
			local cityBuildings = city:GetBuildings();
			if (cityBuildings:HasBuilding(buildingEntry.Hash)) then
				bNeedsPlacement = false;
			end
		end

		if(not pBuildQueue:CanProduce(buildingEntry.Hash, true)) then
			-- For one reason or another we can't produce this, so remove it
			RemoveFromQueue(city:GetID(), 1, true);
			BuildFirstQueued(city);
			return;
		end

		if ( bNeedsPlacement ) then
			-- If so, set the placement mode
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
		else
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
		end
	end

	-- ===========================================================================
	function ZoneDistrict(city, districtEntry)

		local district			:table		= GameInfo.Districts[districtEntry.Hash];
		local bNeedsPlacement	:boolean	= district.RequiresPlacement;
		local pBuildQueue		:table		= city:GetBuildQueue();

		if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
			bNeedsPlacement = false;
		end

		-- Almost all districts need to be placed, but just in case let's check anyway
		if (bNeedsPlacement ) then
			-- If so, set the placement mode
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
		else
			-- If not, add it to the queue.
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	        UI.PlaySound("Confirm_Production");
		end
	end

	-- ===========================================================================
	function AdvanceProject(city, projectEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_PROJECT_TYPE] = projectEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function PurchaseUnit(city, unitEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.STANDARD_MILITARY_FORMATION;
		if (unitEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseUnitCorps(city, unitEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION;
		if (unitEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseUnitArmy(city, unitEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION;
		if (unitEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseBuilding(city, buildingEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
		if (buildingEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseDistrict(city, districtEntry)
		local district			:table		= GameInfo.Districts[districtEntry.Type];
		local bNeedsPlacement	:boolean	= district.RequiresPlacement;
		local pBuildQueue		:table		= city:GetBuildQueue();

		if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
			bNeedsPlacement = false;
		end

		-- Almost all districts need to be placed, but just in case let's check anyway
		if (bNeedsPlacement ) then
			-- If so, set the placement mode
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
		else
			-- If not, add it to the queue.
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	        UI.PlaySound("Purchase_With_Gold");
		end
	end

	-- ===========================================================================
	--	GAME Event
	--	City was selected.
	-- ===========================================================================
	function OnCitySelectionChanged( owner:number, cityID:number, i, j, k, isSelected:boolean, isEditable:boolean)
		local localPlayerId:number = Game.GetLocalPlayer();
		if owner == localPlayerId and isSelected then
			-- Already open then populate with newly selected city's data...
			if (ContextPtr:IsHidden() == false) and Controls.PauseDismissWindow:IsStopped() and Controls.AlphaIn:IsStopped() then
				Refresh();
			end
		end
	end

	-- ===========================================================================
	--	GAME Event
	--	eOldMode, mode the engine was formally in
	--	eNewMode, new mode the engine has just changed to
	-- ===========================================================================
	function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
		-- If this is raised while the city panel is up; selecting to purchase a
		-- plot or manage citizens will close it.
		if eNewMode == InterfaceModeTypes.CITY_MANAGEMENT or eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
			if not ContextPtr:IsHidden() then
				Close();
			end
		end
	end

	-- ===========================================================================
	--	GAME Event
	--	Unit was selected (impossible for a production panel to be up; close it
	-- ===========================================================================
	function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean )
		local localPlayer = Game.GetLocalPlayer();
		if playerID == localPlayer then
			-- If a unit is selected and this is showing; hide it.
			local pSelectedUnit:table = UI.GetHeadSelectedUnit();
			if pSelectedUnit ~= nil and not ContextPtr:IsHidden() then
				OnHide();
			end
		end
	end

	-- ===========================================================================
	--	Actual closing function, may have been called via click, keyboard input,
	--	or an external system call.
	-- ===========================================================================
	function Close()
		if (Controls.SlideIn:IsStopped()) then			-- Need to check to make sure that we have not already begun the transition before attempting to close the panel.
			UI.PlaySound("Production_Panel_Closed");
			Controls.SlideIn:Reverse();
			Controls.AlphaIn:Reverse();

			if(showStandaloneQueueWindow) then
				Controls.QueueSlideIn:Reverse();
				Controls.QueueAlphaIn:Reverse();
			else
				Controls.QueueAlphaIn:SetAlpha(0);
			end

			Controls.PauseDismissWindow:Play();
			LuaEvents.ProductionPanel_Close();
		end
	end

	-- ===========================================================================
	--	Close via click
	function OnClose()
		Close();
	end

	-- ===========================================================================
	--	Open the panel
	-- ===========================================================================
	function Open()
		if ContextPtr:IsHidden() then					-- The ContextPtr is only hidden as a callback to the finished SlideIn animation, so this check should be sufficient to ensure that we are not animating.
			-- Sets up proper selection AND the associated lens so it's not stuck "on".
			UI.PlaySound("Production_Panel_Open");
			LuaEvents.ProductionPanel_Open();
			UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
			Refresh();
			ContextPtr:SetHide(false);
			Controls.ProductionListScroll:SetScrollValue(0);

			-- Size the panel to the maximum Y value of the expanded content
			Controls.AlphaIn:SetToBeginning();
			Controls.SlideIn:SetToBeginning();
			Controls.AlphaIn:Play();
			Controls.SlideIn:Play();

			if(showStandaloneQueueWindow) then
				Controls.QueueAlphaIn:SetToBeginning();
				Controls.QueueSlideIn:SetToBeginning();
				Controls.QueueAlphaIn:Play();
				Controls.QueueSlideIn:Play();
				ResizeQueueWindow();
			end
		end
	end

	-- ===========================================================================
	function OnHide()
		ContextPtr:SetHide(true);
		Controls.PauseDismissWindow:SetToBeginning();
	end


	-- ===========================================================================
	--	Initialize, Refresh, Populate, View
	--	Update the layout based on the view model
	-- ===========================================================================
	function View(data, persistCollapse)
		local selectedCity	= UI.GetHeadSelectedCity();
		-- Get the hashes for the top three recommended items
		m_recommendedItems = selectedCity:GetCityAI():GetBuildRecommendations();
		PopulateList(data, LISTMODE.PRODUCTION, m_listIM);
		PopulateList(data, LISTMODE.PURCHASE_GOLD, m_purchaseListIM);
		PopulateList(data, LISTMODE.PURCHASE_FAITH, m_purchaseFaithListIM);

		if(persistCollapse) then
			if(prodDistrictList ~= nil and not prodDistrictList.HeaderOn:IsHidden()) then
				OnExpand(prodDistrictList);
			end
			if(prodWonderList ~= nil and not prodWonderList.HeaderOn:IsHidden()) then
				OnExpand(prodWonderList);
			end
			if(prodUnitList ~= nil and not prodUnitList.HeaderOn:IsHidden()) then
				OnExpand(prodUnitList);
			end
			if(prodProjectList ~= nil and not prodProjectList.HeaderOn:IsHidden()) then
				OnExpand(prodProjectList);
			end
			if(purchFaithBuildingList ~= nil and not purchFaithBuildingList.HeaderOn:IsHidden()) then
				OnExpand(purchFaithBuildingList);
			end
			if(purchGoldBuildingList ~= nil and not purchGoldBuildingList.HeaderOn:IsHidden()) then
				OnExpand(purchGoldBuildingList);
			end
			if(purchFaithUnitList ~= nil and not purchFaithUnitList.HeaderOn:IsHidden()) then
				OnExpand(purchFaithUnitList);
			end
			if(purchGoldUnitList ~= nil and not purchGoldUnitList.HeaderOn:IsHidden()) then
				OnExpand(purchGoldUnitList);
			end
		else
			if(prodDistrictList ~= nil) then
				OnExpand(prodDistrictList);
			end
			if(prodWonderList ~= nil) then
				OnExpand(prodWonderList);
			end
			if(prodUnitList ~= nil) then
				OnExpand(prodUnitList);
			end
			if(prodProjectList ~= nil) then
				OnExpand(prodProjectList);
			end
			if(purchFaithBuildingList ~= nil) then
				OnExpand(purchFaithBuildingList);
			end
			if(purchGoldBuildingList ~= nil) then
				OnExpand(purchGoldBuildingList);
			end
			if(purchFaithUnitList ~= nil ) then
				OnExpand(purchFaithUnitList);
			end
			if(purchGoldUnitList ~= nil) then
				OnExpand(purchGoldUnitList);
			end

			m_tabs.SelectTab(m_productionTab);
		end


		--

		if( Controls.PurchaseList:GetSizeY() == 0 ) then
			Controls.NoGoldContent:SetHide(false);
		else
			Controls.NoGoldContent:SetHide(true);
		end
		if( Controls.PurchaseFaithList:GetSizeY() == 0 ) then
			Controls.NoFaithContent:SetHide(false);
		else
			Controls.NoFaithContent:SetHide(true);
		end
	end

	function ResetInstanceVisibility(productionItem: table)
		if (productionItem.ArmyCorpsDrawer ~= nil) then
			productionItem.ArmyCorpsDrawer:SetHide(true);
			productionItem.CorpsArmyArrow:SetSelected(true);
			productionItem.CorpsRecommendedIcon:SetHide(true);
			productionItem.CorpsButtonContainer:SetHide(true);
			productionItem.CorpsDisabled:SetHide(true);
			productionItem.ArmyRecommendedIcon:SetHide(true);
			productionItem.ArmyButtonContainer:SetHide(true);
			productionItem.ArmyDisabled:SetHide(true);
			productionItem.CorpsArmyDropdownArea:SetHide(true);
		end
		if (productionItem.BuildingDrawer ~= nil) then
			productionItem.BuildingDrawer:SetHide(true);
			productionItem.CompletedArea:SetHide(true);
		end
		productionItem.RecommendedIcon:SetHide(true);
		productionItem.Disabled:SetHide(true);
	end
	-- ===========================================================================

	function PopulateList(data, listMode, listIM)
		listIM:ResetInstances();
		local districtList;
		local buildingList;
		local wonderList;
		local projectList;
		local unitList;
		local queueList;
		Controls.PauseCollapseList:Stop();
		local selectedCity	= UI.GetHeadSelectedCity();
		local pBuildings = selectedCity:GetBuildings();
		local cityID = selectedCity:GetID();
		local cityData = GetCityData(selectedCity);
		local localPlayer = Players[Game.GetLocalPlayer()];

		if(listMode == LISTMODE.PRODUCTION) then
			m_maxProductionSize = 0;
			-- Populate Current Item
			local buildQueue	= selectedCity:GetBuildQueue();
			local productionHash = 0;
			local completedStr = "";
			local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
			local previousProductionHash = buildQueue:GetPreviousProductionTypeHash();
			local screenX, screenY:number = UIManager:GetScreenSizeVal()

			if( currentProductionHash == 0 and previousProductionHash == 0 ) then
				Controls.CurrentProductionArea:SetHide(true);
				Controls.ProductionListScroll:SetSizeY(screenY-120);
				Controls.ProductionListScroll:CalculateSize();
				Controls.ProductionListScroll:SetOffsetY(10);

				completedStr = "";
			else
				Controls.CurrentProductionArea:SetHide(false);
				Controls.ProductionListScroll:SetSizeY(screenY-175);
				Controls.ProductionListScroll:CalculateSize();
				Controls.ProductionListScroll:SetOffsetY(65);

				if( currentProductionHash == 0 ) then
					productionHash = previousProductionHash;
					Controls.CompletedArea:SetHide(false);
					completedStr = Locale.ToUpper(Locale.Lookup("LOC_TECH_KEY_COMPLETED"));
				else
					Controls.CompletedArea:SetHide(true);
					productionHash = currentProductionHash;
					completedStr = ""
				end
			end

			local currentProductionInfo				:table = GetProductionInfoOfCity( data.City, productionHash );

			if (currentProductionInfo.Icon ~= nil) then
				Controls.CurrentProductionName:SetText(Locale.ToUpper(Locale.Lookup(currentProductionInfo.Name)).." "..completedStr);
				Controls.CurrentProductionProgress:SetPercent(currentProductionInfo.PercentComplete);
				Controls.CurrentProductionProgress:SetShadowPercent(currentProductionInfo.PercentCompleteNextTurn);
				Controls.CurrentProductionIcon:SetIcon(currentProductionInfo.Icon);
				if(currentProductionInfo.Description ~= nil) then
					Controls.CurrentProductionIcon:SetToolTipString(Locale.Lookup(currentProductionInfo.Description));
				else
					Controls.CurrentProductionIcon:SetToolTipString();
				end
				local numberOfTurns = currentProductionInfo.Turns;
				if numberOfTurns == -1 then
					numberOfTurns = "999+";
				end;

				Controls.CurrentProductionCost:SetText("[ICON_Turn]".. numberOfTurns);
				Controls.CurrentProductionProgressString:SetText("[ICON_ProductionLarge]"..currentProductionInfo.Progress.."/"..currentProductionInfo.Cost);
			end

			-- Populate Districts ------------------------ CANNOT purchase districts
			districtList = listIM:GetInstance();
			districtList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS_BUILDINGS")));
			districtList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS_BUILDINGS")));
			local dL = districtList;	-- Due to lambda capture, we need to copy this for callback
			if ( districtList.districtListIM ~= nil ) then
				districtList.districtListIM:ResetInstances();
			else
				districtList.districtListIM = InstanceManager:new( "DistrictListInstance", "Root", districtList.List);
			end

			-- In the interest of performance, we're keeping the instances that we created and resetting the data.
			-- This requires a little bit of footwork to remember the instances that have been modified and to manually reset them.
			for _,type in ipairs(m_TypeNames) do
				if ( districtList[BUILDING_IM_PREFIX..type] ~= nil) then		--Reset the states for the building instance managers
					districtList[BUILDING_IM_PREFIX..type]:ResetInstances();
				end
				if ( districtList[BUILDING_DRAWER_PREFIX..type] ~= nil) then	--Reset the states of the drawers
					districtList[BUILDING_DRAWER_PREFIX..type]:SetHide(true);
				end
			end

			for i, item in ipairs(data.DistrictItems) do
				if(GameInfo.Districts[item.Hash].RequiresPopulation and cityData.DistrictsNum < cityData.DistrictsPossibleNum) then
					if(GetNumDistrictsInCityQueue(selectedCity) + cityData.DistrictsNum >= cityData.DistrictsPossibleNum) then
						item.Disabled = true;
						if(not string.find(item.ToolTip, "COLOR:Red")) then
							item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_DISTRICT_ZONE_POPULATION_TOO_LOW_SHORT", cityData.DistrictsPossibleNum * 3 + 1);
						end
					end
				end

				local districtListing = districtList["districtListIM"]:GetInstance();
				ResetInstanceVisibility(districtListing);
				-- Check to see if this district item is one of the items that is recommended:
				for _,hash in ipairs( m_recommendedItems) do
					if(item.Hash == hash.BuildItemHash) then
						districtListing.RecommendedIcon:SetHide(false);
					end
				end

				local nameStr = Locale.Lookup("{1_Name}", item.Name);
				if (item.Repair) then
					nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
				end
				if (item.Contaminated) then
					nameStr = nameStr .. Locale.Lookup("LOC_PRODUCTION_ITEM_DECONTAMINATE");
				end
				districtListing.LabelText:SetText(nameStr);

				local turnsStrTT:string = "";
				local turnsStr:string = "";

				if(item.HasBeenBuilt and GameInfo.Districts[item.Type].OnePerCity == true and not item.Repair and not item.Contaminated and item.Progress == 0 and not item.TurnsLeft) then
					turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
					turnsStr = "[ICON_Checkmark]";
					districtListing.RecommendedIcon:SetHide(true);
				else
					if(item.TurnsLeft) then
						local numberOfTurns = item.TurnsLeft;
						if numberOfTurns == -1 then
							numberOfTurns = "999+";
							turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
						else
							turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
						end
						turnsStr = numberOfTurns .. "[ICON_Turn]";
					else
						turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
						turnsStr = "[ICON_Checkmark]";
						districtListing.RecommendedIcon:SetHide(true);
					end
				end

				if (item.Disabled) then
					if(item.HasBeenBuilt and GameInfo.Districts[item.Type].OnePerCity == true) then
						turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
						turnsStr = "[ICON_Checkmark]";
					end
				end

				if(item.Progress > 0) then
					districtListing.ProductionProgressArea:SetHide(false);
					local districtProgress = item.Progress/item.Cost;
					if (districtProgress < 1) then
						districtListing.ProductionProgress:SetPercent(districtProgress);
					else
						districtListing.ProductionProgressArea:SetHide(true);
					end
				else
					districtListing.ProductionProgressArea:SetHide(true);
				end

				districtListing.CostText:SetToolTipString(turnsStrTT);
				districtListing.CostText:SetText(turnsStr);
				districtListing.Button:SetToolTipString(item.ToolTip);
				districtListing.Disabled:SetToolTipString(item.ToolTip);
				districtListing.Icon:SetIcon(ICON_PREFIX..item.Type);

				local districtType = item.Type;
				-- Check to see if this is a unique district that will be substituted for another kind of district
				if(GameInfo.DistrictReplaces[item.Type] ~= nil) then
					districtType = 	GameInfo.DistrictReplaces[item.Type].ReplacesDistrictType;
				end
				local uniqueBuildingIMName = BUILDING_IM_PREFIX..districtType;
				local uniqueBuildingAreaName = BUILDING_DRAWER_PREFIX..districtType;

				table.insert(m_TypeNames, districtType);
				districtList[uniqueBuildingIMName] = InstanceManager:new( "BuildingListInstance", "Root", districtListing.BuildingStack);
				districtList[uniqueBuildingAreaName] = districtListing.BuildingDrawer;
				districtListing.CompletedArea:SetHide(true);

				if (item.Disabled) then
					if(item.HasBeenBuilt and GameInfo.Districts[item.Type].OnePerCity == true) then
						districtListing.CompletedArea:SetHide(false);
						districtListing.Disabled:SetHide(true);
					else
						if(showDisabled) then
							districtListing.Disabled:SetHide(false);
							districtListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							districtListing.Root:SetHide(true);
						end
					end
				else
					districtListing.Root:SetHide(false);
					districtListing.Disabled:SetHide(true);
					districtListing.Button:SetColor(0xFFFFFFFF);
				end
				districtListing.Button:SetDisabled(item.Disabled);
				districtListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				districtListing.Button:RegisterCallback( Mouse.eLClick, function()
					if(m_isCONTROLpressed) then
						nextDistrictSkipToFront = true;
					else
						nextDistrictSkipToFront = false;
					end

					QueueDistrict(data.City, item, nextDistrictSkipToFront);
				end);

				districtListing.Button:RegisterCallback( Mouse.eMClick, function()
					nextDistrictSkipToFront = true;
					QueueDistrict(data.City, item, true);
					RecenterCameraToSelectedCity();
				end);

				if(not IsTutorialRunning()) then
					districtListing.Button:RegisterCallback( Mouse.eRClick, function()
						LuaEvents.OpenCivilopedia(item.Type);
					end);
				end

				districtListing.Root:SetTag(UITutorialManager:GetHash(item.Type));
			end

			districtList.List:CalculateSize();
			districtList.List:ReprocessAnchoring();

			if (districtList.List:GetSizeY()==0) then
				districtList.Top:SetHide(true);
			else
				m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
				districtList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(dL);
					end);
				districtList.Header:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				districtList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(dL);
					end);
				districtList.HeaderOn:RegisterCallback(	Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
			end

			prodDistrictList = dL;

			-- Populate Nested Buildings -----------------
			for i, buildingItem in ipairs(data.BuildingItems) do
				local displayItem = true;

				-- PQ: Check if this building is mutually exclusive with another
				if(mutuallyExclusiveBuildings[buildingItem.Type]) then
					for mutuallyExclusiveBuilding in GameInfo.MutuallyExclusiveBuildings() do
						if(mutuallyExclusiveBuilding.Building == buildingItem.Type) then
							if(IsBuildingInQueue(selectedCity, GameInfo.Buildings[mutuallyExclusiveBuilding.MutuallyExclusiveBuilding].Hash) or pBuildings:HasBuilding(GameInfo.Buildings[mutuallyExclusiveBuilding.MutuallyExclusiveBuilding].Index)) then
								displayItem = false;
							end
						elseif(mutuallyExclusiveBuilding.MutuallyExclusiveBuilding == buildingItem.Type) then
							if(IsBuildingInQueue(selectedCity, GameInfo.Buildings[mutuallyExclusiveBuilding.Building].Hash) or pBuildings:HasBuilding(GameInfo.Buildings[mutuallyExclusiveBuilding.Building].Index)) then
								displayItem = false;
							end
						end
					end
				end

				if(buildingItem.Hash == GameInfo.Buildings["BUILDING_PALACE"].Hash) then
					displayItem = false;
				end

				if(not buildingItem.IsWonder and not IsBuildingInQueue(selectedCity, buildingItem.Hash) and displayItem) then
					local uniqueDrawerName = BUILDING_DRAWER_PREFIX..buildingItem.PrereqDistrict;
					local uniqueIMName = BUILDING_IM_PREFIX..buildingItem.PrereqDistrict;
					if (districtList[uniqueIMName] ~= nil) then
						local buildingListing = districtList[uniqueIMName]:GetInstance();
						ResetInstanceVisibility(buildingListing);
						-- Check to see if this is one of the recommended items
						for _,hash in ipairs( m_recommendedItems) do
							if(buildingItem.Hash == hash.BuildItemHash) then
								buildingListing.RecommendedIcon:SetHide(false);
							end
						end
						buildingListing.Root:SetSizeX(305);
						buildingListing.Button:SetSizeX(305);
						local districtBuildingAreaControl = districtList[uniqueDrawerName];
						districtBuildingAreaControl:SetHide(false);

						--Fill the meter if there is any progress, hide it if not
						if(buildingItem.Progress > 0) then
							buildingListing.ProductionProgressArea:SetHide(false);
							local buildingProgress = buildingItem.Progress/buildingItem.Cost;
							if (buildingProgress < 1) then
								buildingListing.ProductionProgress:SetPercent(buildingProgress);
							else
								buildingListing.ProductionProgressArea:SetHide(true);
							end
						else
							buildingListing.ProductionProgressArea:SetHide(true);
						end

						local nameStr = Locale.Lookup("{1_Name}", buildingItem.Name);
						if (buildingItem.Repair) then
							nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
						end
						buildingListing.LabelText:SetText(nameStr);
						local turnsStrTT:string = "";
						local turnsStr:string = "";
						local numberOfTurns = buildingItem.TurnsLeft;
						if numberOfTurns == -1 then
							numberOfTurns = "999+";
							turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
						else
							turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", buildingItem.TurnsLeft);
						end
						turnsStr = numberOfTurns .. "[ICON_Turn]";
						buildingListing.CostText:SetToolTipString(turnsStrTT);
						buildingListing.CostText:SetText(turnsStr);
						buildingListing.Button:SetToolTipString(buildingItem.ToolTip);
						buildingListing.Disabled:SetToolTipString(buildingItem.ToolTip);
						buildingListing.Icon:SetIcon(ICON_PREFIX..buildingItem.Type);
						if (buildingItem.Disabled) then
							if(showDisabled) then
								buildingListing.Disabled:SetHide(false);
								buildingListing.Button:SetColor(COLOR_LOW_OPACITY);
							else
								buildingListing.Button:SetHide(true);
							end
						else
							buildingListing.Button:SetHide(false);
							buildingListing.Disabled:SetHide(true);
							buildingListing.Button:SetSizeY(BUTTON_Y);
							buildingListing.Button:SetColor(0xffffffff);
						end
						buildingListing.Button:SetDisabled(buildingItem.Disabled);
						buildingListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
						buildingListing.Button:RegisterCallback( Mouse.eLClick, function()
							QueueBuilding(data.City, buildingItem);
						end);

						buildingListing.Button:RegisterCallback( Mouse.eMClick, function()
							QueueBuilding(data.City, buildingItem, true);
							RecenterCameraToSelectedCity();
						end);

						if(not IsTutorialRunning()) then
							buildingListing.Button:RegisterCallback( Mouse.eRClick, function()
								LuaEvents.OpenCivilopedia(buildingItem.Type);
							end);
						end

						buildingListing.Button:SetTag(UITutorialManager:GetHash(buildingItem.Type));

					end
				end
			end

			-- Populate Wonders ------------------------ CANNOT purchase wonders
			wonderList = listIM:GetInstance();
			wonderList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_WONDERS")));
			wonderList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_WONDERS")));
			local wL = wonderList;
			if ( wonderList.wonderListIM ~= nil ) then
				wonderList.wonderListIM:ResetInstances()
			else
				wonderList.wonderListIM = InstanceManager:new( "BuildingListInstance", "Root", wonderList.List);
			end

			for i, item in ipairs(data.BuildingItems) do
				if(item.IsWonder and not IsWonderInQueue(item.Hash)) then
					local wonderListing = wonderList["wonderListIM"]:GetInstance();
					ResetInstanceVisibility(wonderListing);
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							wonderListing.RecommendedIcon:SetHide(false);
						end
					end
					local nameStr = Locale.Lookup("{1_Name}", item.Name);
					if (item.Repair) then
						nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
					end
					wonderListing.LabelText:SetText(nameStr);

					if(item.Progress > 0) then
						wonderListing.ProductionProgressArea:SetHide(false);
						local wonderProgress = item.Progress/item.Cost;
						if (wonderProgress < 1) then
							wonderListing.ProductionProgress:SetPercent(wonderProgress);
						else
							wonderListing.ProductionProgressArea:SetHide(true);
						end
					else
						wonderListing.ProductionProgressArea:SetHide(true);
					end
					local turnsStrTT:string = "";
					local turnsStr:string = "";
					local numberOfTurns = item.TurnsLeft;
					if numberOfTurns == -1 then
						numberOfTurns = "999+";
						turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
					else
						turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
					end
					turnsStr = numberOfTurns .. "[ICON_Turn]";
					wonderListing.CostText:SetText(turnsStr);
					wonderListing.CostText:SetToolTipString(turnsStrTT);
					wonderListing.Button:SetToolTipString(item.ToolTip);
					wonderListing.Disabled:SetToolTipString(item.ToolTip);
					wonderListing.Icon:SetIcon(ICON_PREFIX..item.Type);
					if (item.Disabled) then
						if(showDisabled) then
							wonderListing.Disabled:SetHide(false);
							wonderListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							wonderListing.Button:SetHide(true);
						end
					else
						wonderListing.Button:SetHide(false);
						wonderListing.Disabled:SetHide(true);
						wonderListing.Button:SetSizeY(BUTTON_Y);
						wonderListing.Button:SetColor(0xffffffff);
					end
					wonderListing.Button:SetDisabled(item.Disabled);
					wonderListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
					wonderListing.Button:RegisterCallback( Mouse.eLClick, function()
						nextDistrictSkipToFront = false;
						QueueBuilding(data.City, item);
					end);

					wonderListing.Button:RegisterCallback( Mouse.eMClick, function()
						nextDistrictSkipToFront = true;
						QueueBuilding(data.City, item, true);
						RecenterCameraToSelectedCity();
					end);

					if(not IsTutorialRunning()) then
						wonderListing.Button:RegisterCallback( Mouse.eRClick, function()
							LuaEvents.OpenCivilopedia(item.Type);
						end);
					end

					wonderListing.Button:SetTag(UITutorialManager:GetHash(item.Type));
				end
			end

			wonderList.List:CalculateSize();
			wonderList.List:ReprocessAnchoring();

			if (wonderList.List:GetSizeY()==0) then
				wonderList.Top:SetHide(true);
			else
				m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
				wonderList.Header:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				wonderList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(wL);
					end);
				wonderList.HeaderOn:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				wonderList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(wL);
					end);
			end
			prodWonderList = wL;


			--===================================================================================================================
			------------------------------------------ Populate the Production Queue --------------------------------------------
			--===================================================================================================================
			m_queueIM:ResetInstances();
			if(#prodQueue[cityID] > 0) then
				queueList = m_queueIM:GetInstance();

				if (queueList.queueListIM ~= nil) then
					queueList.queueListIM:ResetInstances();
				else
					queueList.queueListIM = InstanceManager:new("QueueListInstance", "Root", queueList.List);
				end

				local itemEncountered = {};

				for i, qi in pairs(prodQueue[cityID]) do
					local queueListing = queueList["queueListIM"]:GetInstance();
					ResetInstanceVisibility(queueListing);
					queueListing.ProductionProgressArea:SetHide(true);

					if(qi.entry) then
						local info = GetProductionInfoOfCity(selectedCity, qi.entry.Hash);
						local turnsText = info.Turns;

						if(itemEncountered[qi.entry.Hash]) then
							turnsText = math.ceil(info.Cost / cityData.ProductionPerTurn);
						else
							if(info.Progress > 0) then
								queueListing.ProductionProgressArea:SetHide(false);

								local progress = info.Progress/info.Cost;
								if (progress < 1) then
									queueListing.ProductionProgress:SetPercent(progress);
								else
									queueListing.ProductionProgressArea:SetHide(true);
								end
							end
						end

						local suffix = "";

						if(GameInfo.Units[qi.entry.Hash]) then
							local unitDef = GameInfo.Units[qi.entry.Hash];
							local cost = 0;

							if(prodQueue[cityID][i].type == PRODUCTION_TYPE.CORPS) then
								cost = qi.entry.CorpsCost;
								if(unitDef.Domain == "DOMAIN_SEA") then
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
								else
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
								end
							elseif(qi.type == PRODUCTION_TYPE.ARMY) then
								cost = qi.entry.ArmyCost;
								if(unitDef.Domain == "DOMAIN_SEA") then
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
								else
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
								end
							elseif(qi.type == PRODUCTION_TYPE.UNIT) then
								cost = qi.entry.Cost;
							end

							if(itemEncountered[qi.entry.Hash] and info.Progress ~= 0) then
								turnsText = math.ceil(cost / cityData.ProductionPerTurn);
								local percentPerTurn = info.PercentCompleteNextTurn - info.PercentComplete;
								if(info.PercentCompleteNextTurn < 1) then
									turnsText = math.ceil(1/percentPerTurn);
								else
									turnsText = "~" .. turnsText;
								end
							else
								turnsText = info.Turns;
								local progress = info.Progress / cost;
								if (progress < 1) then
									queueListing.ProductionProgress:SetPercent(progress);
								end
							end
						end

						if(qi.entry.Repair) then suffix = " (" .. Locale.Lookup("LOC_UNITOPERATION_REPAIR_DESCRIPTION") .. ")" end

						queueListing.LabelText:SetText(Locale.Lookup(qi.entry.Name) .. suffix);
						queueListing.Icon:SetIcon(info.Icon)
						queueListing.CostText:SetText(turnsText .. "[ICON_Turn]");
						if(i == 1) then queueListing.Active:SetHide(false); end

						itemEncountered[qi.entry.Hash] = true;
					end

					-- EVENT HANDLERS --
					queueListing.Button:RegisterCallback( Mouse.eRClick, function()
						if(CanRemoveFromQueue(cityID, i)) then
							if(RemoveFromQueue(cityID, i)) then
								if(i == 1) then
									BuildFirstQueued(selectedCity);
								else
									Refresh(true);
								end
							end
						end
					end);

					queueListing.Button:RegisterCallback( Mouse.eMouseEnter, function()
						if(not UILens.IsLayerOn( LensLayers.DISTRICTS ) and qi.plotID > -1) then
							UILens.SetAdjacencyBonusDistict(qi.plotID, "Placement_Valid", {})
						end
					end);

					queueListing.Button:RegisterCallback( Mouse.eMouseExit, function()
						if(not UILens.IsLayerOn( LensLayers.DISTRICTS )) then
							UILens.ClearLayerHexes( LensLayers.DISTRICTS );
						end
					end);

					queueListing.Button:RegisterCallback( Mouse.eLDblClick, function()
						MoveQueueIndex(cityID, i, 1);
						BuildFirstQueued(selectedCity);
					end);

					queueListing.Button:RegisterCallback( Mouse.eMClick, function()
						MoveQueueIndex(cityID, i, 1);
						BuildFirstQueued(selectedCity);
						RecenterCameraToSelectedCity();
					end);

					queueListing.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnDownInQueue(dragStruct, queueListing, i); end );
					queueListing.Draggable:RegisterCallback( Drag.eDrag, function(dragStruct) OnDragInQueue(dragStruct, queueListing, i); end );
					queueListing.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDropInQueue(dragStruct, queueListing, i); end );
				end
			end
		end --End if LISTMODE.PRODUCTION - display districts, NESTED buildings, and wonders

		if(listMode ~= LISTMODE.PRODUCTION) then			--If we are purchasing, then buildings don't have to be displayed in a nested way

			-- Populate Districts ------------------------
			districtList = listIM:GetInstance();
			districtList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS")));
			districtList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS")));
			local dL = districtList;
			if ( districtList.districtListIM ~= nil) then
				districtList.districtListIM:ResetInstances();
			else
				districtList.districtListIM = InstanceManager:new( "DistrictListInstance", "Root", districtList.List);
			end

			for i, item in ipairs(data.DistrictPurchases) do
				if (item.Yield == "YIELD_GOLD" and listMode == LISTMODE.PURCHASE_GOLD) then
					local districtListing = districtList["districtListIM"]:GetInstance();
					ResetInstanceVisibility(districtListing);
					districtListing.ProductionProgressArea:SetHide(true);
					local nameStr = Locale.Lookup(item.Name);
					local costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.Cost);
					if (item.CantAfford) then
						costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
					end
					for _,hash in ipairs( m_recommendedItems) do
						if (item.Hash == hash.BuildItemHash) then
							districtListing.RecommendedIcon:SetHide(false);
						end
					end
					districtListing.LabelText:SetText(nameStr);
					districtListing.CostText:SetText(costStr);
					districtListing.Button:SetToolTipString(item.ToolTip);
					districtListing.Disabled:SetToolTipString(item.ToolTip);
					districtListing.Icon:SetIcon(ICON_PREFIX..item.Type);
					if (item.Disabled) then
						if(showDisabled) then
							districtListing.Disabled:SetHide(false);
							districtListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							districtListing.Button:SetHide(true);
						end
					else
						districtListing.Button:SetHide(false);
						districtListing.Disabled:SetHide(true);
						districtListing.Button:SetColor(0xffffffff);
					end
					districtListing.Button:SetDisabled(item.Disabled);

					districtListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

					districtListing.Button:RegisterCallback( Mouse.eLClick, function()
							PurchaseDistrict(data.City, item);
						end);

				end
			end

			-- Populate Buildings ------------------------
			buildingList = listIM:GetInstance();
			buildingList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_BUILDINGS")));
			buildingList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_BUILDINGS")));
			local bL = buildingList;
			if ( buildingList.buildingListIM ~= nil ) then
				buildingList.buildingListIM:ResetInstances();
			else
				buildingList.buildingListIM = InstanceManager:new( "BuildingListInstance", "Root", buildingList.List);
			end

			for i, item in ipairs(data.BuildingPurchases) do
				if ((item.Yield == "YIELD_GOLD" and listMode == LISTMODE.PURCHASE_GOLD) or (item.Yield == "YIELD_FAITH" and listMode == LISTMODE.PURCHASE_FAITH)) then
					local buildingListing = buildingList["buildingListIM"]:GetInstance();
					ResetInstanceVisibility(buildingListing);
					buildingListing.ProductionProgressArea:SetHide(true);						-- Since this is DEFINITELY a purchase instance, hide the progress bar
					local nameStr = Locale.Lookup(item.Name);
					local costStr;
					if (item.Yield == "YIELD_GOLD") then
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.Cost);
					else
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.Cost);
					end
					if item.CantAfford then
						costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
					end
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							buildingListing.RecommendedIcon:SetHide(false);
						end
					end
					buildingListing.LabelText:SetText(nameStr);
					buildingListing.CostText:SetText(costStr);
					buildingListing.Button:SetToolTipString(item.ToolTip);
					buildingListing.Disabled:SetToolTipString(item.ToolTip);
					buildingListing.Icon:SetIcon(ICON_PREFIX..item.Type);
					if (item.Disabled) then
						if(showDisabled) then
							buildingListing.Disabled:SetHide(false);
							buildingListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							buildingListing.Button:SetHide(true);
						end
					else
						buildingListing.Button:SetHide(false);
						buildingListing.Disabled:SetHide(true);
						buildingListing.Button:SetColor(0xffffffff);
					end
					buildingListing.Button:SetDisabled(item.Disabled);

					if(not IsTutorialRunning()) then
						buildingListing.Button:RegisterCallback( Mouse.eRClick, function()
							LuaEvents.OpenCivilopedia(item.Type);
						end);
					end

					buildingListing.Button:RegisterCallback( Mouse.eLClick, function()
							PurchaseBuilding(data.City, item);
						end);
				end
			end

			buildingList.List:CalculateSize();
			buildingList.List:ReprocessAnchoring();

			if (buildingList.List:GetSizeY()==0) then
				buildingList.Top:SetHide(true);
			else
				m_maxPurchaseSize = m_maxPurchaseSize + HEADER_Y + SEPARATOR_Y;
				buildingList.Header:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				buildingList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(bL);
					end);
				buildingList.HeaderOn:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				buildingList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(bL);
					end);
			end

			if( listMode== LISTMODE.PURCHASE_GOLD) then
				purchGoldBuildingList = bL;
			elseif (listMode == LISTMODE.PURCHASE_FAITH) then
				purchFaithBuildingList = bL;
			end
		end -- End if NOT LISTMODE.PRODUCTION

		-- Populate Units ------------------------
		local primaryColor, secondaryColor  = UI.GetPlayerColors( Players[Game.GetLocalPlayer()]:GetID() );
		local darkerFlagColor	:number = DarkenLightenColor(primaryColor,(-85),255);
		local brighterFlagColor :number = DarkenLightenColor(primaryColor,90,255);
		local brighterIconColor :number = DarkenLightenColor(secondaryColor,20,255);
		local darkerIconColor	:number = DarkenLightenColor(secondaryColor,-30,255);

		unitList = listIM:GetInstance();
		unitList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_TECH_FILTER_UNITS")));
		unitList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_TECH_FILTER_UNITS")));
		local uL = unitList;
		if ( unitList.unitListIM ~= nil ) then
			unitList.unitListIM:ResetInstances();
		else
			unitList.unitListIM = InstanceManager:new( "UnitListInstance", "Root", unitList.List);
		end
		if ( unitList.civilianListIM ~= nil ) then
			unitList.civilianListIM:ResetInstances();
		else
			unitList.civilianListIM = InstanceManager:new( "CivilianListInstance",	"Root", unitList.List);
		end

		local unitData;
		if(listMode == LISTMODE.PRODUCTION) then
			unitData = data.UnitItems;
		else
			unitData = data.UnitPurchases;
		end
		for i, item in ipairs(unitData) do
			local unitListing;
			if ((item.Yield == "YIELD_GOLD" and listMode == LISTMODE.PURCHASE_GOLD) or (item.Yield == "YIELD_FAITH" and listMode == LISTMODE.PURCHASE_FAITH) or listMode == LISTMODE.PRODUCTION) then

				if (item.Civilian) then
					unitListing = unitList["civilianListIM"]:GetInstance();
				else
					unitListing = unitList["unitListIM"]:GetInstance();
				end
				ResetInstanceVisibility(unitListing);
				-- Check to see if this item is recommended
				for _,hash in ipairs( m_recommendedItems) do
					if(item.Hash == hash.BuildItemHash) then
						unitListing.RecommendedIcon:SetHide(false);
					end
				end

				local costStr = "";
				local costStrTT = "";
				if(listMode == LISTMODE.PRODUCTION) then
					-- ProductionQueue: We need to check that there isn't already one of these in the queue
					if(prodQueue[cityID][1] and prodQueue[cityID][1].entry.Hash == item.Hash) then
						item.TurnsLeft = math.ceil(item.Cost / cityData.ProductionPerTurn);
						item.Progress = 0;
					end

					-- Production meter progress for parent unit
					if(item.Progress > 0) then
						unitListing.ProductionProgressArea:SetHide(false);
						local unitProgress = item.Progress/item.Cost;
						if (unitProgress < 1) then
							unitListing.ProductionProgress:SetPercent(unitProgress);
						else
							unitListing.ProductionProgressArea:SetHide(true);
						end
					else
						unitListing.ProductionProgressArea:SetHide(true);
					end
					local numberOfTurns = item.TurnsLeft;
					if numberOfTurns == -1 then
						numberOfTurns = "999+";
						costStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
					else
						costStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
					end
					costStr = numberOfTurns .. "[ICON_Turn]";
				else
					unitListing.ProductionProgressArea:SetHide(true);
					if (item.Yield == "YIELD_GOLD") then
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.Cost);
					else
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.Cost);
					end
					if item.CantAfford then
						costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
					end
				end

				-- PQ: Check if we already have max spies including queued
				if(item.Hash == GameInfo.Units["UNIT_SPY"].Hash) then
					local localDiplomacy = localPlayer:GetDiplomacy();
					local spyCap = localDiplomacy:GetSpyCapacity();
					local numberOfSpies = 0;

					-- Count our spies
					local localPlayerUnits:table = localPlayer:GetUnits();
					for i, unit in localPlayerUnits:Members() do
						local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
						if unitInfo.Spy then
							numberOfSpies = numberOfSpies + 1;
						end
					end

					-- Loop through all players to see if they have any of our captured spies
					local players:table = Game.GetPlayers();
					for i, player in ipairs(players) do
						local playerDiplomacy:table = player:GetDiplomacy();
						local numCapturedSpies:number = playerDiplomacy:GetNumSpiesCaptured();
						for i=0,numCapturedSpies-1,1 do
							local spyInfo:table = playerDiplomacy:GetNthCapturedSpy(player:GetID(), i);
							if spyInfo and spyInfo.OwningPlayer == Game.GetLocalPlayer() then
								numberOfSpies = numberOfSpies + 1;
							end
						end
					end

					-- Count travelling spies
					if localDiplomacy then
						local numSpiesOffMap:number = localDiplomacy:GetNumSpiesOffMap();
						for i=0,numSpiesOffMap-1,1 do
							local spyOffMapInfo:table = localDiplomacy:GetNthOffMapSpy(Game.GetLocalPlayer(), i);
							if spyOffMapInfo and spyOffMapInfo.ReturnTurn ~= -1 then
								numberOfSpies = numberOfSpies + 1;
							end
						end
					end

	  				if(spyCap > numberOfSpies) then
	  					for _,city in pairs(prodQueue) do
							for _,qi in pairs(city) do
								if(qi.entry.Hash == item.Hash) then
									numberOfSpies = numberOfSpies + 1;
								end
							end
						end
						if(numberOfSpies >= spyCap) then
							item.Disabled = true;
							-- No existing localization string for "Need more spy slots" so we'll just gray it out
							-- item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("???");
						end
	  				end
				end

				-- PQ: Check if we already have max traders queued
				if(item.Hash == GameInfo.Units["UNIT_TRADER"].Hash) then
					local playerTrade	:table	= localPlayer:GetTrade();
					local routesActive	:number = playerTrade:GetNumOutgoingRoutes();
					local routesCapacity:number = playerTrade:GetOutgoingRouteCapacity();
					local routesQueued  :number = 0;

					if(routesCapacity >= routesActive) then
						for _,city in pairs(prodQueue) do
							for _,qi in pairs(city) do
								if(qi.entry.Hash == item.Hash) then
									routesQueued = routesQueued + 1;
								end
							end
						end
						if(routesActive + routesQueued >= routesCapacity) then
							item.Disabled = true;
							if(not string.find(item.ToolTip, "[COLOR:Red]")) then
								item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_UNIT_TRAIN_FULL_TRADE_ROUTE_CAPACITY");
							end
						end
					end
				end

				local nameStr = Locale.Lookup("{1_Name}", item.Name);
				unitListing.LabelText:SetText(nameStr);
				unitListing.CostText:SetText(costStr);
				if(costStrTT ~= "") then
					unitListing.CostText:SetToolTipString(costStrTT);
				end
				unitListing.TrainUnit:SetToolTipString(item.ToolTip);
				unitListing.Disabled:SetToolTipString(item.ToolTip);

				-- Show/hide religion indicator icon
				if unitListing.ReligionIcon then
					local showReligionIcon:boolean = false;

					if item.ReligiousStrength and item.ReligiousStrength > 0 then
						if unitListing.ReligionIcon then
							local religionType = data.City:GetReligion():GetMajorityReligion();
							if religionType > 0 then
								local religion:table = GameInfo.Religions[religionType];
								local religionIcon:string = "ICON_" .. religion.ReligionType;
								local religionColor:number = UI.GetColorValue(religion.Color);

								unitListing.ReligionIcon:SetIcon(religionIcon);
								unitListing.ReligionIcon:SetColor(religionColor);
								unitListing.ReligionIcon:LocalizeAndSetToolTip(religion.Name);
								unitListing.ReligionIcon:SetHide(false);
								showReligionIcon = true;
							end
						end
					end

					unitListing.ReligionIcon:SetHide(not showReligionIcon);
				end

				-- Set Icon color and backing
				local textureName = TEXTURE_BASE;
				if item.Type ~= -1 then
					if (GameInfo.Units[item.Type].Combat ~= 0 or GameInfo.Units[item.Type].RangedCombat ~= 0) then		-- Need a simpler what to test if the unit is a combat unit or not.
						if "DOMAIN_SEA" == GameInfo.Units[item.Type].Domain then
							textureName = TEXTURE_NAVAL;
						else
							textureName =  TEXTURE_BASE;
						end
					else
						if GameInfo.Units[item.Type].MakeTradeRoute then
							textureName = TEXTURE_TRADE;
						elseif "FORMATION_CLASS_SUPPORT" == GameInfo.Units[item.Type].FormationClass then
							textureName = TEXTURE_SUPPORT;
						elseif item.ReligiousStrength > 0 then
							textureName = TEXTURE_RELIGION;
						else
							textureName = TEXTURE_CIVILIAN;
						end
					end
				end

				-- Set colors and icons for the flag instance
				unitListing.FlagBase:SetTexture(textureName);
				unitListing.FlagBaseOutline:SetTexture(textureName);
				unitListing.FlagBaseDarken:SetTexture(textureName);
				unitListing.FlagBaseLighten:SetTexture(textureName);
				unitListing.FlagBase:SetColor( primaryColor );
				unitListing.FlagBaseOutline:SetColor( primaryColor );
				unitListing.FlagBaseDarken:SetColor( darkerFlagColor );
				unitListing.FlagBaseLighten:SetColor( brighterFlagColor );
				unitListing.Icon:SetColor( secondaryColor );
				unitListing.Icon:SetIcon(ICON_PREFIX..item.Type);

				-- Handle if the item is disabled
				if (item.Disabled) then
					if(showDisabled) then
						unitListing.Disabled:SetHide(false);
						unitListing.TrainUnit:SetColor(COLOR_LOW_OPACITY);
						unitListing.RecommendedIcon:SetHide(true);
					else
						unitListing.TrainUnit:SetHide(true);
					end
				else
					unitListing.TrainUnit:SetHide(false);
					unitListing.Disabled:SetHide(true);
					unitListing.TrainUnit:SetColor(0xffffffff);
				end
				unitListing.TrainUnit:SetDisabled(item.Disabled);
				unitListing.TrainUnit:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				if (listMode == LISTMODE.PRODUCTION) then
					unitListing.TrainUnit:RegisterCallback( Mouse.eLClick, function()
						QueueUnit(data.City, item, m_isCONTROLpressed);
						end);

					unitListing.TrainUnit:RegisterCallback( Mouse.eMClick, function()
						QueueUnit(data.City, item, true);
						RecenterCameraToSelectedCity();
						end);
				else
					unitListing.TrainUnit:RegisterCallback( Mouse.eLClick, function()
						PurchaseUnit(data.City, item);
						end);
				end

				if(not IsTutorialRunning()) then
					unitListing.TrainUnit:RegisterCallback( Mouse.eRClick, function()
						LuaEvents.OpenCivilopedia(item.Type);
					end);
				end

				unitListing.TrainUnit:SetTag(UITutorialManager:GetHash(item.Type));

				-- Controls for training unit corps and armies.
				-- Want a special text string for this!! #NEW TEXT #LOCALIZATION - "You can only directly build corps and armies once you have constructed a military academy."
				-- LOC_UNIT_TRAIN_NEED_MILITARY_ACADEMY
				if item.Corps or item.Army then
					--if (item.Disabled) then
					--	if(showDisabled) then
					--		unitListing.CorpsDisabled:SetHide(false);
					--		unitListing.ArmyDisabled:SetHide(false);
					--	end
					--end
					unitListing.CorpsArmyDropdownArea:SetHide(false);
					unitListing.CorpsArmyDropdownButton:RegisterCallback( Mouse.eLClick, function()
							local isExpanded = unitListing.CorpsArmyArrow:IsSelected();
							unitListing.CorpsArmyArrow:SetSelected(not isExpanded);
							unitListing.ArmyCorpsDrawer:SetHide(not isExpanded);
							unitList.List:CalculateSize();
							unitList.List:ReprocessAnchoring();
							unitList.Top:CalculateSize();
							unitList.Top:ReprocessAnchoring();
							if(listMode == LISTMODE.PRODUCTION) then
								Controls.ProductionList:CalculateSize();
								Controls.ProductionListScroll:CalculateSize();
							elseif(listMode == LISTMODE.PURCHASE_GOLD) then
								Controls.PurchaseList:CalculateSize();
								Controls.PurchaseListScroll:CalculateSize();
							elseif(listMode == LISTMODE.PURCHASE_FAITH) then
								Controls.PurchaseFaithList:CalculateSize();
								Controls.PurchaseFaithListScroll:CalculateSize();
							end
							end);
				end

				if item.Corps then
					-- Check to see if this item is recommended
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							unitListing.CorpsRecommendedIcon:SetHide(false);
						end
					end
					unitListing.CorpsButtonContainer:SetHide(false);
					-- Production meter progress for corps unit
					if (listMode == LISTMODE.PRODUCTION) then
						-- ProductionQueue: We need to check that there isn't already one of these in the queue
						if(IsHashInQueue(selectedCity, item.Hash)) then
							item.CorpsTurnsLeft = math.ceil(item.CorpsCost / cityData.ProductionPerTurn);
							item.Progress = 0;
						end

						if(item.Progress > 0) then
							unitListing.ProductionCorpsProgressArea:SetHide(false);
							local unitProgress = item.Progress/item.CorpsCost;
							if (unitProgress < 1) then
								unitListing.ProductionCorpsProgress:SetPercent(unitProgress);
							else
								unitListing.ProductionCorpsProgressArea:SetHide(true);
							end
						else
							unitListing.ProductionCorpsProgressArea:SetHide(true);
						end
						local turnsStr = item.CorpsTurnsLeft .. "[ICON_Turn]";
						local turnsStrTT = item.CorpsTurnsLeft .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.CorpsTurnsLeft);
						unitListing.CorpsCostText:SetText(turnsStr);
						unitListing.CorpsCostText:SetToolTipString(turnsStrTT);
					else
						unitListing.ProductionCorpsProgressArea:SetHide(true);
						if (item.Yield == "YIELD_GOLD") then
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.CorpsCost);
						else
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.CorpsCost);
						end
						if (item.CorpsDisabled) then
							if (showDisabled) then
								unitListing.CorpsDisabled:SetHide(false);
							end
							costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
						end
						unitListing.CorpsCostText:SetText(costStr);
					end


					unitListing.CorpsLabelIcon:SetText(item.CorpsName);
					unitListing.CorpsLabelText:SetText(nameStr);

					unitListing.CorpsFlagBase:SetTexture(textureName);
					unitListing.CorpsFlagBaseOutline:SetTexture(textureName);
					unitListing.CorpsFlagBaseDarken:SetTexture(textureName);
					unitListing.CorpsFlagBaseLighten:SetTexture(textureName);
					unitListing.CorpsFlagBase:SetColor( primaryColor );
					unitListing.CorpsFlagBaseOutline:SetColor( primaryColor );
					unitListing.CorpsFlagBaseDarken:SetColor( darkerFlagColor );
					unitListing.CorpsFlagBaseLighten:SetColor( brighterFlagColor );
					unitListing.CorpsIcon:SetColor( secondaryColor );
					unitListing.CorpsIcon:SetIcon(ICON_PREFIX..item.Type);
					unitListing.TrainCorpsButton:SetToolTipString(item.CorpsTooltip);
					unitListing.CorpsDisabled:SetToolTipString(item.CorpsTooltip);
					if (listMode == LISTMODE.PRODUCTION) then
						unitListing.TrainCorpsButton:RegisterCallback( Mouse.eLClick, function()
							QueueUnitCorps(data.City, item);
						end);

						unitListing.TrainCorpsButton:RegisterCallback( Mouse.eMClick, function()
							QueueUnitCorps(data.City, item, true);
							RecenterCameraToSelectedCity();
						end);
					else
						unitListing.TrainCorpsButton:RegisterCallback( Mouse.eLClick, function()
							PurchaseUnitCorps(data.City, item);
						end);
					end
				end
				if item.Army then
					-- Check to see if this item is recommended
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							unitListing.ArmyRecommendedIcon:SetHide(false);
						end
					end
					unitListing.ArmyButtonContainer:SetHide(false);

					if (listMode == LISTMODE.PRODUCTION) then
						-- ProductionQueue: We need to check that there isn't already one of these in the queue
						if(IsHashInQueue(selectedCity, item.Hash)) then
							item.ArmyTurnsLeft = math.ceil(item.ArmyCost / cityData.ProductionPerTurn);
							item.Progress = 0;
						end

						if(item.Progress > 0) then
							unitListing.ProductionArmyProgressArea:SetHide(false);
							local unitProgress = item.Progress/item.ArmyCost;
							unitListing.ProductionArmyProgress:SetPercent(unitProgress);
							if (unitProgress < 1) then
								unitListing.ProductionArmyProgress:SetPercent(unitProgress);
							else
								unitListing.ProductionArmyProgressArea:SetHide(true);
							end
						else
							unitListing.ProductionArmyProgressArea:SetHide(true);
						end
						local turnsStrTT:string = "";
						local turnsStr:string = "";
						local numberOfTurns = item.ArmyTurnsLeft;
						if numberOfTurns == -1 then
							numberOfTurns = "999+";
							turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
						else
							turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.ArmyTurnsLeft);
						end
						turnsStr = numberOfTurns .. "[ICON_Turn]";
						unitListing.ArmyCostText:SetText(turnsStr);
						unitListing.ArmyCostText:SetToolTipString(turnsStrTT);
					else
						unitListing.ProductionArmyProgressArea:SetHide(true);
						if (item.Yield == "YIELD_GOLD") then
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.ArmyCost);
						else
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.ArmyCost);
						end
						if (item.ArmyDisabled) then
							if (showDisabled) then
								unitListing.ArmyDisabled:SetHide(false);
							end
							costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
						end
						unitListing.ArmyCostText:SetText(costStr);
					end

					unitListing.ArmyLabelIcon:SetText(item.ArmyName);
					unitListing.ArmyLabelText:SetText(nameStr);
					unitListing.ArmyFlagBase:SetTexture(textureName);
					unitListing.ArmyFlagBaseOutline:SetTexture(textureName);
					unitListing.ArmyFlagBaseDarken:SetTexture(textureName);
					unitListing.ArmyFlagBaseLighten:SetTexture(textureName);
					unitListing.ArmyFlagBase:SetColor( primaryColor );
					unitListing.ArmyFlagBaseOutline:SetColor( primaryColor );
					unitListing.ArmyFlagBaseDarken:SetColor( darkerFlagColor );
					unitListing.ArmyFlagBaseLighten:SetColor( brighterFlagColor );
					unitListing.ArmyIcon:SetColor( secondaryColor );
					unitListing.ArmyIcon:SetIcon(ICON_PREFIX..item.Type);
					unitListing.TrainArmyButton:SetToolTipString(item.ArmyTooltip);
					unitListing.ArmyDisabled:SetToolTipString(item.ArmyTooltip);
					if (listMode == LISTMODE.PRODUCTION) then
						unitListing.TrainArmyButton:RegisterCallback( Mouse.eLClick, function()
							QueueUnitArmy(data.City, item);
						end);

						unitListing.TrainArmyButton:RegisterCallback( Mouse.eMClick, function()
							QueueUnitArmy(data.City, item, true);
							RecenterCameraToSelectedCity();
						end);
					else
						unitListing.TrainArmyButton:RegisterCallback( Mouse.eLClick, function()
							PurchaseUnitArmy(data.City, item);
						end);
					end
				end
			end -- end faith/gold check
		end -- end iteration through units

		unitList.List:CalculateSize();
		unitList.List:ReprocessAnchoring();

		if (unitList.List:GetSizeY()==0) then
			unitList.Top:SetHide(true);
		else
			m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
			unitList.Header:RegisterCallback( Mouse.eLClick, function()
				OnExpand(uL);
				end);
			unitList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
				OnCollapse(uL);
				end);
		end

		if( listMode== LISTMODE.PURCHASE_GOLD) then
			purchGoldUnitList = uL;
		elseif (listMode == LISTMODE.PURCHASE_FAITH) then
			purchFaithUnitList = uL;
		else
			prodUnitList = uL;
		end

		if(listMode == LISTMODE.PRODUCTION) then			--Projects can only be produced, not purchased
			-- Populate Projects ------------------------
			projectList = listIM:GetInstance();
			projectList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_PROJECTS")));
			projectList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_PROJECTS")));
			local pL = projectList;
			if ( projectList.projectListIM ~= nil ) then
				projectList.projectListIM:ResetInstances();
			else
				projectList.projectListIM = InstanceManager:new( "ProjectListInstance", "Root", projectList.List);
			end

			-- Check for queued project and list it as well
			-- if(prodQueue[cityID] and prodQueue[cityID][1] and GameInfo.Projects[prodQueue[cityID][1].entry.Hash]) then
			-- 	local activeQueueItem = prodQueue[cityID][1].entry;
			-- 	table.insert(data.ProjectItems, activeQueueItem);
			-- end

			for i, item in ipairs(data.ProjectItems) do
				local projectListing = projectList.projectListIM:GetInstance();
				ResetInstanceVisibility(projectListing);
				-- Check to see if this item is recommended
				for _,hash in ipairs( m_recommendedItems) do
					if(item.Hash == hash.BuildItemHash) then
						projectListing.RecommendedIcon:SetHide(false);
					end
				end

				-- ProductionQueue: We need to check that there isn't already one of these in the queue
				if(IsHashInQueue(selectedCity, item.Hash)) then
					item.TurnsLeft = math.ceil(item.Cost / cityData.ProductionPerTurn);
					item.Progress = 0;
				end

				-- Production meter progress for project
				if(item.Progress > 0) then
					projectListing.ProductionProgressArea:SetHide(false);
					local projectProgress = item.Progress/item.Cost;
					if (projectProgress < 1) then
						projectListing.ProductionProgress:SetPercent(projectProgress);
					else
						projectListing.ProductionProgressArea:SetHide(true);
					end
				else
					projectListing.ProductionProgressArea:SetHide(true);
				end

				local numberOfTurns = item.TurnsLeft;
				if numberOfTurns == -1 then
					numberOfTurns = "999+";
				end;

				local nameStr = Locale.Lookup("{1_Name}", item.Name);
				local turnsStr = numberOfTurns .. "[ICON_Turn]";
				projectListing.LabelText:SetText(nameStr);
				projectListing.CostText:SetText(turnsStr);
				projectListing.Button:SetToolTipString(item.ToolTip);
				projectListing.Disabled:SetToolTipString(item.ToolTip);
				projectListing.Icon:SetIcon(ICON_PREFIX..item.Type);
				if (item.Disabled) then
					if(showDisabled) then
						projectListing.Disabled:SetHide(false);
						projectListing.Button:SetColor(COLOR_LOW_OPACITY);
					else
						projectListing.Button:SetHide(true);
					end
				else
					projectListing.Button:SetHide(false);
					projectListing.Disabled:SetHide(true);
					projectListing.Button:SetColor(0xffffffff);
				end
				projectListing.Button:SetDisabled(item.Disabled);
				projectListing.Button:RegisterCallback( Mouse.eLClick, function()
					QueueProject(data.City, item);
				end);

				projectListing.Button:RegisterCallback( Mouse.eMClick, function()
					QueueProject(data.City, item, true);
					RecenterCameraToSelectedCity();
				end);

				if(not IsTutorialRunning()) then
					projectListing.Button:RegisterCallback( Mouse.eRClick, function()
						LuaEvents.OpenCivilopedia(item.Type);
					end);
				end

				projectListing.Button:SetTag(UITutorialManager:GetHash(item.Type));
			end


			projectList.List:CalculateSize();
			projectList.List:ReprocessAnchoring();

			if (projectList.List:GetSizeY()==0) then
				projectList.Top:SetHide(true);
			else
				m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
				projectList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(pL);
					end);
				projectList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(pL);
					end);
			end

			prodProjectList = pL;
		end -- end if LISTMODE.PRODUCTION

		-----------------------------------
		if( listMode == LISTMODE.PRODUCTION) then
			m_maxProductionSize = m_maxProductionSize + districtList.List:GetSizeY() + unitList.List:GetSizeY() + projectList.List:GetSizeY();
		end
		Controls.ProductionList:CalculateSize();
		Controls.ProductionListScroll:CalculateSize();
		Controls.PurchaseList:CalculateSize();
		Controls.PurchaseListScroll:CalculateSize();
		Controls.PurchaseFaithList:CalculateSize();
		Controls.PurchaseFaithListScroll:CalculateSize();

		-- DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		--for _,data in ipairs( m_recommendedItems) do
		--	if(GameInfo.Types[data.BuildItemHash].Type ~= nil) then
		--		print("Hash = ".. GameInfo.Types[data.BuildItemHash].Type);
		--	else
		--		print("Invalid hash received = " .. data.BuildItemHash);
		--	end
		--end
		-- DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	end

	function OnLocalPlayerChanged()
		Refresh();
	end

	function OnPlayerTurnActivated(player, isFirstTimeThisTurn)
		if (isFirstTimeThisTurn and Game.GetLocalPlayer() == player) then
			CheckAndReplaceAllQueuesForUpgrades();
			Refresh();
			lastProductionCompletePerCity = {};
		end
	end

	-- Returns ( allReasons:string )
	function ComposeFailureReasonStrings( isDisabled:boolean, results:table )
		if isDisabled and results ~= nil then
			-- Are there any failure reasons?
			local pFailureReasons : table = results[CityCommandResults.FAILURE_REASONS];
			if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
				-- Collect them all!
				local allReasons : string = "";
				for i,v in ipairs(pFailureReasons) do
					allReasons = allReasons .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
				end
				return allReasons;
			end
		end
		return "";
	end
	function ComposeProductionCostString( iProductionProgress:number, iProductionCost:number)
		-- Show production progress only if there is progress present
		if iProductionCost ~= 0 then
			local TXT_COST			:string = Locale.Lookup( "LOC_HUD_PRODUCTION_COST" );
			local TXT_PRODUCTION	:string = Locale.Lookup( "LOC_HUD_PRODUCTION" );
			local costString		:string = tostring(iProductionCost);

			if iProductionProgress > 0 then -- Only show fraction if build progress has been made.
				costString = tostring(iProductionProgress) .. "/" .. costString;
			end
			return "[NEWLINE][NEWLINE]" .. TXT_COST .. ": " .. costString .. " [ICON_Production] " .. TXT_PRODUCTION;
		end
		return "";
	end
	-- Returns ( tooltip:string, subtitle:string )
	function ComposeUnitCorpsStrings( sUnitName:string, sUnitDomain:string, iProdProgress:number, iCorpsCost:number )
		local tooltip	:string = Locale.Lookup( sUnitName ) .. " ";
		local subtitle	:string = "";
		if sUnitDomain == "DOMAIN_SEA" then
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
			subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX") .. ")";
		else
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
			subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX") .. ")";
		end
		tooltip = tooltip .. "[NEWLINE]---" .. ComposeProductionCostString( iProdProgress, iCorpsCost );
		return tooltip, subtitle;
	end
	function ComposeUnitArmyStrings( sUnitName:string, sUnitDomain:string, iProdProgress:number, iArmyCost:number )
		local tooltip	:string = Locale.Lookup( sUnitName ) .. " ";
		local subtitle	:string = "";
		if sUnitDomain == "DOMAIN_SEA" then
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
			subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX")..")";
		else
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
			subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX")..")";
		end
		tooltip = tooltip .. "[NEWLINE]---" .. ComposeProductionCostString( iProdProgress, iArmyCost );
		return tooltip, subtitle;
	end

	-- Returns ( isPurchaseable:boolean, kEntry:table )
	function ComposeUnitForPurchase( row:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
		local YIELD_TYPE 	:number = GameInfo.Yields[sYield].Index;

		-- Should we display this option to the player?
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = row.Hash;
		tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
		if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
			local isCanStart, results			 = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
			local isDisabled			:boolean = not isCanStart;
			local allReasons			 :string = ComposeFailureReasonStrings( isDisabled, results );
			local sToolTip 				 :string = ToolTipHelper.GetUnitToolTip( row.Hash ) .. allReasons;
			local isCantAfford			:boolean = false;
			--print ( "UnitBuy ", row.UnitType,isCanStart );

			-- Collect some constants so we don't need to keep calling out to get them.
			local nCityID				:number = pCity:GetID();
			local pCityGold				 :table = pCity:GetGold();
			local TXT_INSUFFIENT_YIELD	:string = "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup( sCantAffordKey ) .. "[ENDCOLOR]";

			-- Affordability check
			if not pYieldSource:CanAfford( nCityID, row.Hash ) then
				sToolTip = sToolTip .. TXT_INSUFFIENT_YIELD;
				isDisabled = true;
				isCantAfford = true;
			end

			local pBuildQueue			:table  = pCity:GetBuildQueue();
			local nProductionCost		:number = pBuildQueue:GetUnitCost( row.Index );
			local nProductionProgress	:number = pBuildQueue:GetUnitProgress( row.Index );
			sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

			local kUnit	 :table = {
				Type				= row.UnitType;
				Name				= row.Name;
				ToolTip				= sToolTip;
				Hash				= row.Hash;
				Kind				= row.Kind;
				Civilian			= row.FormationClass == "FORMATION_CLASS_CIVILIAN";
				Disabled			= isDisabled;
				CantAfford			= isCantAfford,
				Yield				= sYield;
				Cost				= pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.STANDARD_MILITARY_FORMATION );
				ReligiousStrength	= row.ReligiousStrength;

				CorpsTurnsLeft	= 0;
				ArmyTurnsLeft	= 0;
				Progress		= 0;
			};

			-- Should we present options for building Corps or Army versions?
			if results ~= nil then
				kUnit.Corps = results[CityOperationResults.CAN_TRAIN_CORPS];
				kUnit.Army = results[CityOperationResults.CAN_TRAIN_ARMY];

				local nProdProgress	:number = pBuildQueue:GetUnitProgress( row.Index );
				if kUnit.Corps then
					local nCost = pBuildQueue:GetUnitCorpsCost( row.Index );
					kUnit.CorpsCost	= pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
					kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row.Name, row.Domain, nProdProgress, nCost );
					kUnit.CorpsDisabled = not pYieldSource:CanAfford( nCityID, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
					if kUnit.CorpsDisabled then
						kUnit.CorpsTooltip = kUnit.CorpsTooltip .. TXT_INSUFFIENT_YIELD;
					end
				end

				if kUnit.Army then
					local nCost = pBuildQueue:GetUnitArmyCost( row.Index );
					kUnit.ArmyCost	= pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
					kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row.Name, row.Domain, nProdProgress, nCost );
					kUnit.ArmyDisabled = not pYieldSource:CanAfford( nCityID, row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
					if kUnit.ArmyDisabled then
						kUnit.ArmyTooltip = kUnit.ArmyTooltip .. TXT_INSUFFIENT_YIELD;
					end
				end
			end

			return true, kUnit;
		end
		return false, nil;
	end
	function ComposeBldgForPurchase( pRow:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
		local YIELD_TYPE 	:number = GameInfo.Yields[sYield].Index;

		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = pRow.Hash;
		tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
		if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
			local isCanStart, pResults		 = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
			local isDisabled		:boolean = not isCanStart;
			local sAllReasons		 :string = ComposeFailureReasonStrings( isDisabled, pResults );
			local sToolTip 			 :string = ToolTipHelper.GetBuildingToolTip( pRow.Hash, playerID, pCity ) .. sAllReasons;
			local isCantAfford		:boolean = false;

			-- Affordability check
			if not pYieldSource:CanAfford( cityID, pRow.Hash ) then
				sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(sCantAffordKey) .. "[ENDCOLOR]";
				isDisabled = true;
				isCantAfford = true;
			end

			local pBuildQueue			:table  = pCity:GetBuildQueue();
			local iProductionCost		:number = pBuildQueue:GetBuildingCost( pRow.Index );
			local iProductionProgress	:number = pBuildQueue:GetBuildingProgress( pRow.Index );
			sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

			local kBuilding :table = {
				Type			= pRow.BuildingType,
				Name			= pRow.Name,
				ToolTip			= sToolTip,
				Hash			= pRow.Hash,
				Kind			= pRow.Kind,
				Disabled		= isDisabled,
				CantAfford		= isCantAfford,
				Cost			= pCity:GetGold():GetPurchaseCost( YIELD_TYPE, pRow.Hash ),
				Yield			= sYield
			};
			return true, kBuilding;
		end
		return false, nil;
	end

	function ComposeDistrictForPurchase( pRow:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
		local YIELD_TYPE 	:number = GameInfo.Yields[sYield].Index;

		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_DISTRICT_TYPE] = pRow.Hash;
		tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
		if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
			local isCanStart, pResults		 = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
			local isDisabled		:boolean = not isCanStart;
			local sAllReasons		:string = ComposeFailureReasonStrings( isDisabled, pResults );
			local sToolTip 			:string = ToolTipHelper.GetDistrictToolTip( pRow.Hash ) .. sAllReasons;
			local isCantAfford		:boolean = false;

			-- Affordability check
			if not pYieldSource:CanAfford( cityID, pRow.Hash ) then
				sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(sCantAffordKey) .. "[ENDCOLOR]";
				isDisabled = true;
				isCantAfford = true;
			end

			local pBuildQueue			:table  = pCity:GetBuildQueue();
			local iProductionCost		:number = pBuildQueue:GetDistrictCost( pRow.Index );
			local iProductionProgress	:number = pBuildQueue:GetDistrictProgress( pRow.Index );
			sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

			local kDistrict :table = {
				Type			= pRow.DistrictType,
				Name			= pRow.Name,
				ToolTip			= sToolTip,
				Hash			= pRow.Hash,
				Kind			= pRow.Kind,
				Disabled		= isDisabled,
				CantAfford		= isCantAfford,
				Cost			= pCity:GetGold():GetPurchaseCost( YIELD_TYPE, pRow.Hash ),
				Yield			= sYield
			};
			return true, kDistrict;
		end
		return false, nil;
	end
	-- ===========================================================================
	function Refresh(persistCollapse)
		local playerID	:number = Game.GetLocalPlayer();
		local pPlayer	:table = Players[playerID];
		if (pPlayer == nil) then
			return;
		end

		local selectedCity	= UI.GetHeadSelectedCity();

		if (selectedCity ~= nil) then
			local cityGrowth	= selectedCity:GetGrowth();
			local cityCulture	= selectedCity:GetCulture();
			local buildQueue	= selectedCity:GetBuildQueue();
			local playerTreasury= pPlayer:GetTreasury();
			local playerReligion= pPlayer:GetReligion();
			local cityGold		= selectedCity:GetGold();
			local cityBuildings = selectedCity:GetBuildings();
			local cityDistricts = selectedCity:GetDistricts();
			local cityID		= selectedCity:GetID();
			local cityData 		= GetCityData(selectedCity);
			local cityPlot 		= Map.GetPlot(selectedCity:GetX(), selectedCity:GetY());

			if(not prodQueue[cityID]) then prodQueue[cityID] = {}; end
			CheckAndReplaceQueueForUpgrades(selectedCity);

			local new_data = {
				City				= selectedCity,
				Population			= selectedCity:GetPopulation(),
				Owner				= selectedCity:GetOwner(),
				Damage				= pPlayer:GetDistricts():FindID( selectedCity:GetDistrictID() ):GetDamage(),
				TurnsUntilGrowth	= cityGrowth:GetTurnsUntilGrowth(),
				CurrentTurnsLeft	= buildQueue:GetTurnsLeft(),
				FoodSurplus			= cityGrowth:GetFoodSurplus(),
				CulturePerTurn		= cityCulture:GetCultureYield(),
				TurnsUntilExpansion = cityCulture:GetTurnsUntilExpansion(),
				DistrictItems		= {},
				BuildingItems		= {},
				UnitItems			= {},
				ProjectItems		= {},
				BuildingPurchases	= {},
				UnitPurchases		= {},
				DistrictPurchases	= {},
			};

			local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();

			for row in GameInfo.Districts() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end

				local isInPanelList 		:boolean = not row.InternalOnly;
				local bHasProducedDistrict	:boolean = cityDistricts:HasDistrict( row.Index );
				local isInQueue 			:boolean = IsHashInQueue( selectedCity, row.Hash );
				local turnsLeft 			:number	 = buildQueue:GetTurnsLeft( row.DistrictType );
				if (isInPanelList or isInQueue) and ( buildQueue:CanProduce( row.Hash, true ) or bHasProducedDistrict or isInQueue ) then
					local isCanProduceExclusion, results = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled			:boolean = not isCanProduceExclusion;

					if(isInQueue) then
						bHasProducedDistrict = true;
						turnsLeft = nil;
						isDisabled = true;
					end

					-- If at least one valid plot is found where the district can be built, consider it buildable.
					local plots :table = GetCityRelatedPlotIndexesDistrictsAlternative( selectedCity, row.Hash );
					if plots == nil or table.count(plots) == 0 then
						-- No plots available for district. Has player had already started building it?
						local isPlotAllocated :boolean = false;
						local pDistricts 		:table = selectedCity:GetDistricts();
						for _, pCityDistrict in pDistricts:Members() do
							if row.Index == pCityDistrict:GetType() then
								isPlotAllocated = true;
								break;
							end
						end
						-- If not, this district can't be built. Guarantee that isDisabled is set.
						if not isPlotAllocated then
							isDisabled = true;
						end
					end

					local allReasons			:string = ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip				:string = ToolTipHelper.GetToolTip(row.DistrictType, Game.GetLocalPlayer()) .. allReasons;

					local iProductionCost		:number = buildQueue:GetDistrictCost( row.Index );
					local iProductionProgress	:number = buildQueue:GetDistrictProgress( row.Index );
					sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

					table.insert( new_data.DistrictItems, {
						Type			= row.DistrictType,
						Name			= row.Name,
						ToolTip			= sToolTip,
						Hash			= row.Hash,
						Kind			= row.Kind,
						TurnsLeft		= turnsLeft,
						Disabled		= isDisabled,
						Repair			= cityDistricts:IsPillaged( row.Index ),
						Contaminated	= cityDistricts:IsContaminated( row.Index ),
						Cost			= iProductionCost,
						Progress		= iProductionProgress,
						HasBeenBuilt	= bHasProducedDistrict
					});
				end

				-- Can it be purchased with gold?
				local isAllowed, kDistrict = ComposeDistrictForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
				if isAllowed then
					table.insert( new_data.DistrictPurchases, kDistrict );
				end

			end

			for row in GameInfo.Buildings() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end

				-- PQ: Determine if we have requirements in the queue
				local hasPrereqTech = row.PrereqTech == nil;
				local hasPrereqCivic = row.PrereqCivic == nil;
				local isPrereqDistrictInQueue = false;
				local disabledTooltip = nil;
				local doShow = true;

				if(not row.IsWonder) then
					local prereqTech = GameInfo.Technologies[row.PrereqTech];
					local prereqCivic = GameInfo.Civics[row.PrereqCivic];
					local prereqDistrict = GameInfo.Districts[row.PrereqDistrict];

					if(prereqTech and pPlayer:GetTechs():HasTech(prereqTech.Index)) then hasPrereqTech = true; end
					if(prereqCivic and pPlayer:GetCulture():HasCivic(prereqCivic.Index)) then hasPrereqCivic = true; end
					if((prereqDistrict and IsHashInQueue( selectedCity, prereqDistrict.Hash)) or cityDistricts:HasDistrict(prereqDistrict.Index, true)) then
						isPrereqDistrictInQueue = true;

						if(not IsHashInQueue( selectedCity, prereqDistrict.Hash )) then
							if(cityDistricts:IsPillaged(prereqDistrict.Index)) then
								disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_PILLAGED");
							elseif(cityDistricts:IsContaminated(prereqDistrict.Index)) then
								disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_CONTAMINATED");
							end
						end
					end

					if(not isPrereqDistrictInQueue) then
						for replacesRow in GameInfo.DistrictReplaces() do
							if(row.PrereqDistrict == replacesRow.ReplacesDistrictType) then
								local replacementDistrict = GameInfo.Districts[replacesRow.CivUniqueDistrictType];
								if((replacementDistrict and IsHashInQueue( selectedCity, replacementDistrict.Hash)) or cityDistricts:HasDistrict(replacementDistrict.Index, true)) then
									isPrereqDistrictInQueue = true;

									if(not IsHashInQueue( selectedCity, replacementDistrict.Hash )) then
										if(cityDistricts:IsPillaged(replacementDistrict.Index)) then
											disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_PILLAGED");
										elseif(cityDistricts:IsContaminated(replacementDistrict.Index)) then
											disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_CONTAMINATED");
										end
									end
								end
								break;
							end
						end
					end

					if(not isPrereqDistrictInQueue) then
						local canBuild, reasons = buildQueue:CanProduce(row.BuildingType, false, true);
						if(not canBuild and reasons) then
							local pFailureReasons = reasons[CityCommandResults.FAILURE_REASONS];
							if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
								for i,v in ipairs(pFailureReasons) do
									if("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED" == v) then
										disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED");
									end
								end
							end
						end
					end

					local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
					-- Check for unique buildings
					for replaceRow in GameInfo.BuildingReplaces() do
						if(replaceRow.CivUniqueBuildingType == row.BuildingType) then
							local traitName = "TRAIT_CIVILIZATION_" .. row.BuildingType;
							local isCorrectCiv = false;

							for traitRow in GameInfo.CivilizationTraits() do
								if(traitRow.TraitType == traitName and traitRow.CivilizationType == civTypeName) then
									isCorrectCiv = true;
									break;
								end
							end

							if(not isCorrectCiv) then
								doShow = false;
							end
						end

						if(replaceRow.ReplacesBuildingType == row.BuildingType) then
							local traitName = "TRAIT_CIVILIZATION_" .. replaceRow.CivUniqueBuildingType;
							local isCorrectCiv = false;

							for traitRow in GameInfo.CivilizationTraits() do
								if(traitRow.TraitType == traitName and traitRow.CivilizationType == civTypeName) then
									isCorrectCiv = true;
									break;
								end
							end

							if(isCorrectCiv) then
								doShow = false;
							end
						end
					end

					-- Check for building prereqs
					if(buildingPrereqs[row.BuildingType]) then
						local prereqInQueue = false;

						for prereqRow in GameInfo.BuildingPrereqs() do
							if(prereqRow.Building == row.BuildingType) then
								for replaceRow in GameInfo.BuildingReplaces() do
									if(replaceRow.ReplacesBuildingType == prereqRow.PrereqBuilding and IsHashInQueue(selectedCity, GameInfo.Buildings[replaceRow.CivUniqueBuildingType].Hash)) then
										prereqInQueue = true;
										break;
									end
								end

								if(prereqInQueue or IsHashInQueue(selectedCity, GameInfo.Buildings[prereqRow.PrereqBuilding].Hash)) then
									prereqInQueue = true;

									-- Check for buildings enabled by dominant religious beliefs
									if(GameInfo.Buildings[row.Hash].EnabledByReligion) then
										doShow = false;

										if ((table.count(cityData.Religions) > 1) or (cityData.PantheonBelief > -1)) then
											local modifierIDs = {};

											if cityData.PantheonBelief > -1 then
												local beliefType = GameInfo.Beliefs[cityData.PantheonBelief].BeliefType;
												for belief in GameInfo.BeliefModifiers() do
													if belief.BeliefType == beliefType then
														table.insert(modifierIDs, belief.ModifierID);
														break;
													end
												end
											end
											if (table.count(cityData.Religions) > 0) then
												for _, beliefIndex in ipairs(cityData.BeliefsOfDominantReligion) do
													local beliefType = GameInfo.Beliefs[beliefIndex].BeliefType;
													for belief in GameInfo.BeliefModifiers() do
														if belief.BeliefType == beliefType then
															table.insert(modifierIDs, belief.ModifierID);
														end
													end
												end
											end

											if(#modifierIDs > 0) then
												for i=#modifierIDs, 1, -1 do
													if(string.find(modifierIDs[i], "ALLOW_")) then
														modifierIDs[i] = string.gsub(modifierIDs[i], "ALLOW", "BUILDING");
														if(row.BuildingType == string.gsub(modifierIDs[i], "ALLOW", "BUILDING")) then
															doShow = true;
														end
													end
												end
											end
										end
									end

									break;
								end
							end
						end

						if(not prereqInQueue) then doShow = false; end
					end

					-- Check for river adjacency requirement
					if (row.RequiresAdjacentRiver and not cityPlot:IsRiver()) then
						doShow = false;
					end

					-- Check for wall obsolescence
					if(row.OuterDefenseHitPoints and pPlayer:GetCulture():HasCivic(GameInfo.Civics["CIVIC_CIVIL_ENGINEERING"].Index)) then
						doShow = false;
					end

					-- Check for internal only buildings
					if(row.InternalOnly) then doShow = false end

					-- Check that the player has a government of an adequate tier
					if(row.GovernmentTierRequirement) then
						local eSelectedPlayerGovernmentId:number = pPlayer:GetCulture():GetCurrentGovernment();
						if eSelectedPlayerGovernmentId ~= -1 then
							local selectedPlayerGovernment = GameInfo.Governments[eSelectedPlayerGovernmentId];
							if(selectedPlayerGovernment.Tier) then
								local eSelectedPlayerGovernmentTier:number = tonumber(string.sub(selectedPlayerGovernment.Tier, 5));
								local buildingGovernmentTierRequirement:number = tonumber(string.sub(row.GovernmentTierRequirement, 5));

								if(eSelectedPlayerGovernmentTier < buildingGovernmentTierRequirement) then
									doShow = false;
								end
							else
								doShow = false;
							end
						else
							doShow = false;
						end
					end

					-- Check if it's been built already
					if(hasPrereqTech and hasPrereqCivic and isPrereqDistrictInQueue and doShow) then
						for _, district in ipairs(cityData.BuildingsAndDistricts) do
							if district.isBuilt then
								local match = false;

								for _,building in ipairs(district.Buildings) do
									if(building.Name == Locale.Lookup(row.Name)) then
										if(building.isBuilt and not building.isPillaged) then
											doShow = false;
										else
											doShow = true;
										end

										match = true;
										break;
									end
								end

								if(match) then break; end
							end
						end
					else
						doShow = false;
					end
				end

				if not row.MustPurchase and ( buildQueue:CanProduce( row.Hash, true ) or (doShow and not row.IsWonder) ) then
					local isCanStart, results			 = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled			:boolean = false;

					if(row.IsWonder or not doShow) then
						isDisabled = not isCanStart;
					end

					local allReasons			 :string = ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip 				 :string = ToolTipHelper.GetBuildingToolTip( row.Hash, playerID, selectedCity ) .. allReasons;

					local iProductionCost		:number = buildQueue:GetBuildingCost( row.Index );
					local iProductionProgress	:number = buildQueue:GetBuildingProgress( row.Index );

					if(disabledTooltip) then
						isDisabled = true;
						if(not string.find(sToolTip, "COLOR:Red")) then
							sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. disabledTooltip .. "[ENDCOLOR]";
						end
					end

					sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

					local iPrereqDistrict = "";
					if row.PrereqDistrict ~= nil then
						iPrereqDistrict = row.PrereqDistrict;
					end

					table.insert( new_data.BuildingItems, {
						Type			= row.BuildingType,
						Name			= row.Name,
						ToolTip			= sToolTip,
						Hash			= row.Hash,
						Kind			= row.Kind,
						TurnsLeft		= buildQueue:GetTurnsLeft( row.Hash ),
						Disabled		= isDisabled,
						Repair			= cityBuildings:IsPillaged( row.Hash ),
						Cost			= iProductionCost,
						Progress		= iProductionProgress,
						IsWonder		= row.IsWonder,
						PrereqDistrict	= iPrereqDistrict }
					);
				end

				-- Can it be purchased with gold?
				if row.PurchaseYield == "YIELD_GOLD" then
					local isAllowed, kBldg = ComposeBldgForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
					if isAllowed then
						table.insert( new_data.BuildingPurchases, kBldg );
					end
				end
				-- Can it be purchased with faith?
				if row.PurchaseYield == "YIELD_FAITH" or cityGold:IsBuildingFaithPurchaseEnabled( row.Hash ) then
					local isAllowed, kBldg = ComposeBldgForPurchase( row, selectedCity, "YIELD_FAITH", playerReligion, "LOC_BUILDING_INSUFFICIENT_FAITH" );
					if isAllowed then
						table.insert( new_data.BuildingPurchases, kBldg );
					end
				end
			end

			for row in GameInfo.Units() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end
				-- Can it be built normally?
				if not row.MustPurchase and buildQueue:CanProduce( row.Hash, true ) then
					local isCanProduceExclusion, results	 = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled				:boolean = not isCanProduceExclusion;
					local sAllReasons				 :string = ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip					 :string = ToolTipHelper.GetUnitToolTip( row.Hash ) .. sAllReasons;

					local nProductionCost		:number = buildQueue:GetUnitCost( row.Index );
					local nProductionProgress	:number = buildQueue:GetUnitProgress( row.Index );
					sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

					local kUnit :table = {
						Type				= row.UnitType,
						Name				= row.Name,
						ToolTip				= sToolTip,
						Hash				= row.Hash,
						Kind				= row.Kind,
						TurnsLeft			= buildQueue:GetTurnsLeft( row.Hash ),
						Disabled			= isDisabled,
						Civilian			= row.FormationClass == "FORMATION_CLASS_CIVILIAN",
						Cost				= nProductionCost,
						Progress			= nProductionProgress,
						Corps				= false,
						CorpsCost			= 0,
						CorpsTurnsLeft		= 1,
						CorpsTooltip		= "",
						CorpsName			= "",
						Army				= false,
						ArmyCost			= 0,
						ArmyTurnsLeft		= 1,
						ArmyTooltip			= "",
						ArmyName			= "",
						ReligiousStrength	= row.ReligiousStrength
					};

					-- Should we present options for building Corps or Army versions?
					if results ~= nil then
						if results[CityOperationResults.CAN_TRAIN_CORPS] then
							kUnit.Corps			= true;
							kUnit.CorpsCost		= buildQueue:GetUnitCorpsCost( row.Index );
							kUnit.CorpsTurnsLeft	= buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
							kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row.Name, row.Domain, nProductionProgress, kUnit.CorpsCost );
						end
						if results[CityOperationResults.CAN_TRAIN_ARMY] then
							kUnit.Army			= true;
							kUnit.ArmyCost		= buildQueue:GetUnitArmyCost( row.Index );
							kUnit.ArmyTurnsLeft	= buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
							kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row.Name, row.Domain, nProductionProgress, kUnit.ArmyCost );
						end
					end

					table.insert(new_data.UnitItems, kUnit );
				end

				-- Can it be purchased with gold?
				if row.PurchaseYield == "YIELD_GOLD" then
					local isAllowed, kUnit = ComposeUnitForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
					if isAllowed then
						table.insert( new_data.UnitPurchases, kUnit );
					end
				end
				-- Can it be purchased with faith?
				if row.PurchaseYield == "YIELD_FAITH" or cityGold:IsUnitFaithPurchaseEnabled( row.Hash ) then
					local isAllowed, kUnit = ComposeUnitForPurchase( row, selectedCity, "YIELD_FAITH", playerReligion, "LOC_BUILDING_INSUFFICIENT_FAITH" );
					if isAllowed then
						table.insert( new_data.UnitPurchases, kUnit );
					end
				end
			end

			for row in GameInfo.Projects() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end

				if buildQueue:CanProduce( row.Hash, true ) and not (row.MaxPlayerInstances and IsHashInAnyQueue(row.Hash)) then
					local isCanProduceExclusion, results = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled			:boolean = not isCanProduceExclusion;

					local allReasons		:string	= ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip			:string = ToolTipHelper.GetProjectToolTip( row.Hash ) .. allReasons;

					local iProductionCost		:number = buildQueue:GetProjectCost( row.Index );
					local iProductionProgress	:number = buildQueue:GetProjectProgress( row.Index );
					sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

					table.insert(new_data.ProjectItems, {
						Type			= row.ProjectType,
						Name			= row.Name,
						ToolTip			= sToolTip,
						Hash			= row.Hash,
						Kind			= row.Kind,
						TurnsLeft		= buildQueue:GetTurnsLeft( row.ProjectType ),
						Disabled		= isDisabled,
						Cost			= iProductionCost,
						Progress		= iProductionProgress
					});
				end
			end

			View(new_data, persistCollapse);
			ResizeQueueWindow();
			SaveQueues();
		end
	end

	-- ===========================================================================
	function ShowHideDisabled()
		--Controls.HideDisabled:SetSelected(showDisabled);
		showDisabled = not showDisabled;
		Refresh();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelChooseProduction()
		if (ContextPtr:IsHidden()) then
			Refresh();
		else
			if (m_tabs.selectedControl ~= m_productionTab) then
				m_tabs.SelectTab(m_productionTab);
			end
		end
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnNotificationPanelChooseProduction()
			if ContextPtr:IsHidden() then
			Open();

		--else																--TESTING TO SEE IF THIS FIXES OUR TUTORIAL BUG.
		--	if Controls.PauseDismissWindow:IsStopped() then
		--		Close();
		--	else
		--		Controls.PauseDismissWindow:Stop();
		--		Open();
		--	end
		end
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelChoosePurchase()
		if (ContextPtr:IsHidden()) then
			Refresh();
			OnTabChangePurchase();
			m_tabs.SelectTab(m_purchaseTab);
		else
			if (m_tabs.selectedControl ~= m_purchaseTab) then
				OnTabChangePurchase();
				m_tabs.SelectTab(m_purchaseTab);
			end
		end
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelChoosePurchaseFaith()
		if (ContextPtr:IsHidden()) then
			Refresh();
			OnTabChangePurchaseFaith();
			m_tabs.SelectTab(m_faithTab);
		else
			if (m_tabs.selectedControl ~= m_faithTab) then
				OnTabChangePurchaseFaith();
				m_tabs.SelectTab(m_faithTab);
			end
		end
	end

	-- ===========================================================================
	--	LUA Event
	--	Outside source is signaling production should be closed if open.
	-- ===========================================================================
	function OnProductionClose()
		if not ContextPtr:IsHidden() then
			Close();
		end
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city banner (anchored to world view)
	-- ===========================================================================
	function OnCityBannerManagerProductionToggle()
		m_isQueueMode = false;
		if(ContextPtr:IsHidden()) then
			Open();
		else
		end
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city information panel
	-- ===========================================================================
	function OnCityPanelProductionOpen()
		m_isQueueMode = false;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city information panel - Purchase with faith check
	-- ===========================================================================
	function OnCityPanelPurchaseFaithOpen()
		m_isQueueMode = false;
		Open();
		m_tabs.SelectTab(m_faithTab);
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city information panel - Purchase with gold check
	-- ===========================================================================
	function OnCityPanelPurchaseGoldOpen()
		m_isQueueMode = false;
		Open();
		m_tabs.SelectTab(m_purchaseTab);
	end
	-- ===========================================================================
	--	LUA Event
	--	Production opened from a placement
	-- ===========================================================================
	function OnStrategicViewMapPlacementProductionOpen()
		m_isQueueMode = false;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnTutorialProductionOpen()
		m_isQueueMode = false;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnProductionOpenForQueue()
		m_isQueueMode = true;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelPurchasePlot()
		Close();
	end

	-- ===========================================================================
	--	LUA Event
	--	Set cached values back after a hotload.
	-- ===========================================================================
	function OnGameDebugReturn( context:string, contextTable:table )
		if context ~= RELOAD_CACHE_ID then return; end
		m_isQueueMode = contextTable["m_isQueueMode"];
		local isHidden:boolean = contextTable["isHidden"];
		if not isHidden then
			Refresh();
		end
	end

	-- ===========================================================================
	--	Keyboard INPUT Up Handler
	-- ===========================================================================
	function KeyUpHandler( key:number )
		if (key == Keys.VK_ESCAPE) then Close(); return true; end
		if (key == Keys.VK_CONTROL) then m_isCONTROLpressed = false; return true; end
		return false;
	end

	-- ===========================================================================
	--	Keyboard INPUT Down Handler
	-- ===========================================================================
	function KeyDownHandler( key:number )
		if (key == Keys.VK_CONTROL) then m_isCONTROLpressed = true; return true; end
		return false;
	end

	-- ===========================================================================
	--	UI Event
	-- ===========================================================================
	function OnInputHandler( pInputStruct:table )
		local uiMsg = pInputStruct:GetMessageType();
		if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end;
		if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end;
		return false;
	end

	-- ===========================================================================
	--	UI Event
	-- ===========================================================================
	function OnInit( isReload:boolean )
		if isReload then
			LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
		end
	end

	-- ===========================================================================
	--	UI Event
	-- ===========================================================================
	function OnShutdown()
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "m_isQueueMode", m_isQueueMode );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "prodQueue", prodQueue );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "isHidden",		ContextPtr:IsHidden() );
	end


	-- ===========================================================================
	-- ===========================================================================
	function Resize()
		--local contentSize = (m_maxProductionSize > m_maxPurchaseSize) and m_maxProductionSize or m_maxPurchaseSize;
		--contentSize = contentSize + WINDOW_HEADER_Y;
		--local w,h = UIManager:GetScreenSizeVal();
		--local maxAllowable = h - Controls.Window:GetOffsetY() - TOPBAR_Y;
		--local panelSizeY = (contentSize < maxAllowable) and contentSize or maxAllowable;
		--Controls.Window:SetSizeY(panelSizeY);
		--Controls.ProductionListScroll:SetSizeY(panelSizeY-Controls.WindowContent:GetOffsetY());
		--Controls.PurchaseListScroll:SetSizeY(panelSizeY-Controls.WindowContent:GetOffsetY());
		--Controls.DropShadow:SetSizeY(panelSizeY+100);
	end

	-- ===========================================================================
	-- ===========================================================================
	function CreateCorrectTabs()
		local MAX_TAB_LABEL_WIDTH = 273;
		local productionLabelX = Controls.ProductionTab:GetTextControl():GetSizeX();
		local purchaseLabelX = Controls.PurchaseTab:GetTextControl():GetSizeX();
		local purchaseFaithLabelX = Controls.PurchaseFaithTab:GetTextControl():GetSizeX();
		local tabAnimControl;
		local tabArrowControl;
		local tabSizeX;
		local tabSizeY;

		Controls.ProductionTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.PurchaseTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.PurchaseFaithTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.MiniProductionTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.MiniPurchaseTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.MiniPurchaseFaithTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

		Controls.MiniProductionTab:SetHide(true);
		Controls.MiniPurchaseTab:SetHide(true);
		Controls.MiniPurchaseFaithTab:SetHide(true);
		Controls.ProductionTab:SetHide(true);
		Controls.PurchaseTab:SetHide(true);
		Controls.PurchaseFaithTab:SetHide(true);
		Controls.MiniTabAnim:SetHide(true);
		Controls.MiniTabArrow:SetHide(true);
		Controls.TabAnim:SetHide(true);
		Controls.TabArrow:SetHide(true);

		local labelWidth = productionLabelX + purchaseLabelX;
		if GameCapabilities.HasCapability("CAPABILITY_FAITH") then
			labelWidth = labelWidth + purchaseFaithLabelX;
		end
		if(labelWidth > MAX_TAB_LABEL_WIDTH) then
			tabSizeX = 44;
			tabSizeY = 44;
			Controls.MiniProductionTab:SetHide(false);
			Controls.MiniPurchaseTab:SetHide(false);
			Controls.MiniPurchaseFaithTab:SetHide(false);
			Controls.MiniTabAnim:SetHide(false);
			Controls.MiniTabArrow:SetHide(false);
			m_productionTab = Controls.MiniProductionTab;
			m_purchaseTab	= Controls.MiniPurchaseTab;
			m_faithTab		= Controls.MiniPurchaseFaithTab;
			tabAnimControl	= Controls.MiniTabAnim;
			tabArrowControl = Controls.MiniTabArrow;
		else
			tabSizeX = 42;
			tabSizeY = 34;
			Controls.ProductionTab:SetHide(false);
			Controls.PurchaseTab:SetHide(false);
			Controls.PurchaseFaithTab:SetHide(false);
			Controls.TabAnim:SetHide(false);
			Controls.TabArrow:SetHide(false);
			m_productionTab = Controls.ProductionTab;
			m_purchaseTab	= Controls.PurchaseTab;
			m_faithTab		= Controls.PurchaseFaithTab;
			tabAnimControl	= Controls.TabAnim;
			tabArrowControl = Controls.TabArrow;
		end
		m_tabs = CreateTabs( Controls.TabRow, tabSizeX, tabSizeY, 0xFF331D05 );
		m_tabs.AddTab( m_productionTab,	OnTabChangeProduction );
		if GameCapabilities.HasCapability("CAPABILITY_GOLD") then
			m_tabs.AddTab( m_purchaseTab,	OnTabChangePurchase );
		else
			Controls.PurchaseTab:SetHide(true);
			Controls.MiniPurchaseTab:SetHide(true);
		end
		if GameCapabilities.HasCapability("CAPABILITY_FAITH") then
			m_tabs.AddTab( m_faithTab,	OnTabChangePurchaseFaith );
		else
			Controls.MiniPurchaseFaithTab:SetHide(true);
			Controls.PurchaseFaithTab:SetHide(true);
		end
		m_tabs.CenterAlignTabs(0);
		m_tabs.SelectTab( m_productionTab );
		m_tabs.AddAnimDeco(tabAnimControl, tabArrowControl);
	end


	--- =========================================================================================================
	--  ====================================== PRODUCTION QUEUE MOD FUNCTIONS ===================================
	--- =========================================================================================================

	--- =======================================================================================================
	--  === Production event handlers
	--- =======================================================================================================

	--- ===========================================================================
	--	Fires when a city's current production changes
	--- ===========================================================================
	function OnCityProductionChanged(playerID:number, cityID:number)
		Refresh();
	end

	function OnCityProductionUpdated( ownerPlayerID:number, cityID:number, eProductionType, eProductionObject)
		if(ownerPlayerID ~= Game.GetLocalPlayer()) then return end
		lastProductionCompletePerCity[cityID] = nil;
	end

	--- ===========================================================================
	--	Fires when a city's production is completed
	--  Note: This seems to sometimes fire more than once for a turn
	--- ===========================================================================
	function OnCityProductionCompleted(playerID, cityID, orderType, unitType, canceled, typeModifier)
		if (playerID ~= Game.GetLocalPlayer()) then return end;

		local pPlayer = Players[ playerID ];
		if (pPlayer == nil) then return end;

		local pCity = pPlayer:GetCities():FindID(cityID);
		if (pCity == nil) then return end;

		local currentTurn = Game.GetCurrentGameTurn();

		-- Only one item can be produced per turn per city
		if(lastProductionCompletePerCity[cityID] and lastProductionCompletePerCity[cityID] == currentTurn) then
			return;
		end

		if(prodQueue[cityID] and prodQueue[cityID][1]) then
			-- Check that the production is actually completed
			local productionInfo = GetProductionInfoOfCity(pCity, prodQueue[cityID][1].entry.Hash);
			local pDistricts = pCity:GetDistricts();
			local pBuildings = pCity:GetBuildings();
			local isComplete = false;

			if(prodQueue[cityID][1].type == PRODUCTION_TYPE.BUILDING or prodQueue[cityID][1].type == PRODUCTION_TYPE.PLACED) then
				if(GameInfo.Districts[prodQueue[cityID][1].entry.Hash] and pDistricts:HasDistrict(GameInfo.Districts[prodQueue[cityID][1].entry.Hash].Index, true)) then
					isComplete = true;
				elseif(GameInfo.Buildings[prodQueue[cityID][1].entry.Hash] and pBuildings:HasBuilding(GameInfo.Buildings[prodQueue[cityID][1].entry.Hash].Index)) then
					isComplete = true;
				elseif(productionInfo.PercentComplete >= 1) then
					isComplete = true;
				end

				if(not isComplete) then
					return;
				end
			end

			-- PQ: Experimental
			local productionType = prodQueue[cityID][1].type;
			if(orderType == 0) then
				if(productionType == PRODUCTION_TYPE.UNIT or productionType == PRODUCTION_TYPE.CORPS or productionType == PRODUCTION_TYPE.ARMY) then
					if(GameInfo.Units[prodQueue[cityID][1].entry.Hash].Index == unitType) then
						isComplete = true;
					end
				end
			elseif(orderType == 1) then
				-- Building/wonder
				if(productionType == PRODUCTION_TYPE.BUILDING or productionType == PRODUCTION_TYPE.PLACED) then
					local buildingInfo = GameInfo.Buildings[prodQueue[cityID][1].entry.Hash];
					if(buildingInfo and buildingInfo.Index == unitType) then
						isComplete = true;
					end
				end

					-- Check if this building is in our queue at all
				if(not isComplete and IsHashInQueue(pCity, GameInfo.Buildings[unitType].Hash)) then
					local removeIndex = GetIndexOfHashInQueue(pCity, GameInfo.Buildings[unitType].Hash);
					RemoveFromQueue(cityID, removeIndex, true);

					if(removeIndex == 1) then
						BuildFirstQueued(pCity);
					else
						Refresh(true);
					end

					SaveQueues();
					return;
				end
			elseif(orderType == 2) then
				-- District
				if(productionType == PRODUCTION_TYPE.PLACED) then
					local districtInfo = GameInfo.Districts[prodQueue[cityID][1].entry.Hash];
					if(districtInfo and districtInfo.Index == unitType) then
						isComplete = true;
					end
				end
			elseif(orderType == 3) then
				-- Project
				if(productionType == PRODUCTION_TYPE.PROJECT) then
					local projectInfo = GameInfo.Projects[prodQueue[cityID][1].entry.Hash];
					if(projectInfo and projectInfo.Index == unitType) then
						isComplete = true;
					end
				end
			end

			if(not isComplete) then
				Refresh(true);
				return;
			end

			table.remove(prodQueue[cityID], 1);
			if(#prodQueue[cityID] > 0) then
				BuildFirstQueued(pCity);
			end

			lastProductionCompletePerCity[cityID] = currentTurn;
			SaveQueues();
		end
	end


	--- =======================================================================================================
	--  === Load/Save
	--- =======================================================================================================

	--- ==========================================================================
	--  Updates the PlayerConfiguration with all ProductionQueue data
	--- ==========================================================================
	function SaveQueues()
		PlayerConfigurations[Game.GetLocalPlayer()]:SetValue("ZenProductionQueue", DataDumper(prodQueue, "prodQueue"));
	end

	--- ==========================================================================
	--  Loads ProductionQueue data from PlayerConfiguration, and populates the
	--  queue with current production information if saved info not present
	--- ==========================================================================
	function LoadQueues()
		local localPlayerID = Game.GetLocalPlayer();
		if(PlayerConfigurations[localPlayerID]:GetValue("ZenProductionQueue") ~= nil) then
			loadstring(PlayerConfigurations[localPlayerID]:GetValue("ZenProductionQueue"))();
		end

		if(not prodQueue) then
			prodQueue = {};
		end

	 	local player = Players[localPlayerID];
	 	local cities = player:GetCities();

	 	for j, city in cities:Members() do
	 		local cityID = city:GetID();
	 		local buildQueue = city:GetBuildQueue();
	 		local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
	 		local plotID = -1;

	 		if(not prodQueue[cityID]) then
	 			prodQueue[cityID] = {};
	 		end

	 		if(not prodQueue[cityID][1] and currentProductionHash ~= 0) then
	 			-- Determine the type of the item
	 			local currentType = 0;
	 			local productionInfo = GetProductionInfoOfCity(city, currentProductionHash);
	 			productionInfo.Hash = currentProductionHash;

	 			if(productionInfo.Type == "UNIT") then
	 				currentType = buildQueue:GetCurrentProductionTypeModifier() + 2;
				elseif(productionInfo.Type == "BUILDING") then
					if(GameInfo.Buildings[currentProductionHash].MaxWorldInstances == 1) then
						currentType = PRODUCTION_TYPE.PLACED;

						local pCityBuildings	:table = city:GetBuildings();
						local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( city );
						if (kCityPlots ~= nil) then
							for _,plot in pairs(kCityPlots) do
								local kPlot:table =  Map.GetPlotByIndex(plot);
								local wonderType = kPlot:GetWonderType();
								if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == GameInfo.Buildings[currentProductionHash].BuildingType) then
									plotID = plot;
								end
							end
						end
					else
						currentType = PRODUCTION_TYPE.BUILDING;
					end
				elseif(productionInfo.Type == "DISTRICT") then
					currentType = PRODUCTION_TYPE.PLACED;
				elseif(productionInfo.Type == "PROJECT") then
					currentType = PRODUCTION_TYPE.PROJECT;
	 			end

	 			if(currentType == 0) then
	 				print("Could not find production type for hash: " .. currentProductionHash);
	 			end

	 			prodQueue[cityID][1] = {
	 				entry=productionInfo,
	 				type=currentType,
	 				plotID=plotID
	 			}

			elseif(currentProductionHash == 0) then
	 		end
		end

		-- Populate our table for building prerequisites
		for prereqRow in GameInfo.BuildingPrereqs() do
			buildingPrereqs[prereqRow.Building] = 1;
		end

		for building in GameInfo.MutuallyExclusiveBuildings() do
			mutuallyExclusiveBuildings[building.Building] = 1;
		end
	end


	--- =======================================================================================================
	--  === Queue information
	--- =======================================================================================================

	--- ===========================================================================
	--	Checks if there is a specific building hash in a city's Production Queue
	--- ===========================================================================
	function IsBuildingInQueue(city, buildingHash)
		local cityID = city:GetID();

		if(prodQueue and #prodQueue[cityID] > 0) then
			for _, qi in pairs(prodQueue[cityID]) do
				if(qi.entry and qi.entry.Hash == buildingHash) then
					if(qi.type == PRODUCTION_TYPE.BUILDING or qi.type == PRODUCTION_TYPE.PLACED) then
						return true;
					end
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Checks if there is a specific wonder hash in all Production Queues
	--- ===========================================================================
	function IsWonderInQueue(wonderHash)
		for _,city in pairs(prodQueue) do
			for _, qi in pairs(city) do
				if(qi.entry and qi.entry.Hash == wonderHash) then
					if(qi.type == PRODUCTION_TYPE.PLACED) then
						return true;
					end
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Checks if there is a specific hash in all Production Queues
	--- ===========================================================================
	function IsHashInAnyQueue(hash)
		for _,city in pairs(prodQueue) do
			for _, qi in pairs(city) do
				if(qi.entry and qi.entry.Hash == hash) then
					return true;
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Checks if there is a specific item hash in a city's Production Queue
	--- ===========================================================================
	function IsHashInQueue(city, hash)
		local cityID = city:GetID();

		if(prodQueue and #prodQueue[cityID] > 0) then
			for i, qi in pairs(prodQueue[cityID]) do
				if(qi.entry and qi.entry.Hash == hash) then
					return true;
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Returns the first instance of a hash in a city's Production Queue
	--- ===========================================================================
	function GetIndexOfHashInQueue(city, hash)
		local cityID = city:GetID();

		if(prodQueue and #prodQueue[cityID] > 0) then
			for i, qi in pairs(prodQueue[cityID]) do
				if(qi.entry and qi.entry.Hash == hash) then
					return i;
				end
			end
		end
		return nil;
	end

	--- ===========================================================================
	--	Get the total number of districts (requiring population)
	--  in a city's Production Queue still requiring placement
	--- ===========================================================================
	function GetNumDistrictsInCityQueue(city)
		local numDistricts = 0;
		local cityID = city:GetID();
		local pBuildQueue = city:GetBuildQueue();

		if(#prodQueue[cityID] > 0) then
			for _,qi in pairs(prodQueue[cityID]) do
				if(GameInfo.Districts[qi.entry.Hash] and GameInfo.Districts[qi.entry.Hash].RequiresPopulation) then
					if (not pBuildQueue:HasBeenPlaced(qi.entry.Hash)) then
						numDistricts = numDistricts + 1;
					end
				end
			end
		end

		return numDistricts;
	end

	--- =============================================================================
	--  [Doing it this way is ridiculous and hacky but I am tired; Please forgive me]
	--  Checks the Production Queue for matching reserved plots
	--- =============================================================================
	GameInfo.Districts['DISTRICT_CITY_CENTER'].IsPlotValid = function(pCity, plotID)
		local cityID = pCity:GetID();

		if(#prodQueue[cityID] > 0) then
			for j,item in ipairs(prodQueue[cityID]) do
				if(item.plotID == plotID) then
					return false;
				end
			end
		end
		return true;
	end







	--- =======================================================================================================
	--  === Drag and Drop - Highlighting
	--- =======================================================================================================
	function HighlightActiveQueueItem_DropTarget( tTargetInstance:table )
		local nTargetSlot :number = tTargetInstance and tTargetInstance.ButtonContainer.id or -1;
		if( nTargetSlot ~= m_PrevDropTargetSlot) then
			if ( m_PrevDropTargetSlot ~= -1 ) then
				-- m_PrevDropTargetInstance.HoverArrow:SetShow( false );
				m_PrevDropTargetInstance.Draggable:SetOffsetX(0);
			end
			if ( tTargetInstance ) then
				-- tTargetInstance.HoverArrow:SetShow( true );
				tTargetInstance.Draggable:SetOffsetX(-10);
			end
			m_PrevDropTargetSlot = nTargetSlot;
			m_PrevDropTargetInstance = tTargetInstance;
		end
	end





	--- =======================================================================================================
	--  === Drag and Drop
	--- =======================================================================================================
	function GetCurrentDragTarget( tDraggedControl:table, index:number )
		local tViableDragTargets :table = {}; -- also is its own map to get parent table from specific control.
		local cityID = UI.GetHeadSelectedCity():GetID();

		-- We now need to loop through the controls for each queue item to pass to the new Drag'n'Drop system
		if(#m_queueIM.m_AllocatedInstances < 1) then
			-- There are no queue instances... bail
		else
			for i,tQueueControl in ipairs(m_queueIM.m_AllocatedInstances[1].queueListIM.m_AllocatedInstances) do
				if(i ~= index) then
					tQueueControl.ButtonContainer.id = i;
					tQueueControl.ButtonContainer.Instance = tQueueControl;
					table.insert( tViableDragTargets, tQueueControl.ButtonContainer );
				end
			end
		end

		local tBestTarget :table = DragSupport_GetBestOverlappingControl( tDraggedControl, tViableDragTargets );
		return tBestTarget;
	end


	--- ===========================================================================
	--	Fires when picking up an item in the Production Queue
	--- ===========================================================================
	function OnDownInQueue( dragStruct:table, queueListing:table, index:number )
		UI.PlaySound("Play_UI_Click");
		HighlightActiveQueueItem_DropTarget(nil);
	end

	--- ===========================================================================
	--	Fires when dragging an item in the Production Queue
	--- ===========================================================================
	function OnDragInQueue( dragStruct:table, queueListing:table, index:number )
		local dragControl:table  = dragStruct:GetControl();
		local tAcceptableTarget	 :table = nil;

		if dragControl then
			tAcceptableTarget = GetCurrentDragTarget( dragControl, index );
			tAcceptableTarget = tAcceptableTarget and tAcceptableTarget.Instance or nil;
		end
		HighlightActiveQueueItem_DropTarget( tAcceptableTarget );
	end

	--- ===========================================================================
	--	Fires when dropping an item in the Production Queue
	--- ===========================================================================
	function OnDropInQueue( dragStruct:table, queueListing:table, index:number )
		local dragControl:table	 = dragStruct:GetControl();
		local tViableDragTargets :table = {};
		local city = UI.GetHeadSelectedCity();
		local cityID = city:GetID();

		table.insert( tViableDragTargets, Controls.ProductionQueuePanel );
		local tBest :table = DragSupport_GetBestOverlappingControl( dragControl, tViableDragTargets );

		if(tBest ~= nil) then
			local tTargetQueueItem :table = GetCurrentDragTarget(dragControl, index);

			if(tTargetQueueItem ~= nil and index ~= tTargetQueueItem.id) then
				-- If the target is valid, swap them
				MoveQueueIndex(cityID, index, tTargetQueueItem.id);
				dragControl:StopSnapBack();
				if(index == 1 or tTargetQueueItem.id == 1) then
					BuildFirstQueued(city);
				else
					Refresh(true);
				end
			elseif(not tTargetQueueItem or index == tTargetQueueItem.id) then
				-- Dropped on itself, just abort
			end
		else
			-- Dropped off the panel entirely; remove from queue
			dragControl:StopSnapBack();
			RemoveFromQueue(cityID, index);
			BuildFirstQueued(city);
			Refresh();
		end

		HighlightActiveQueueItem_DropTarget(nil);
		UI.PlaySound("Main_Menu_Mouse_Over");
	end

	--- =======================================================================================================
	--  === Queueing/Building
	--- =======================================================================================================

	--- ==========================================================================
	--  Adds unit of given type to the Production Queue and builds it if requested
	--- ==========================================================================
	function QueueUnitOfType(city, unitEntry, unitType, skipToFront)
		local cityID = city:GetID();
		local index = 1;

		if(not prodQueue[cityID]) then prodQueue[cityID] = {}; end
		if(not skipToFront) then index = #prodQueue[cityID] + 1; end

		table.insert(prodQueue[cityID], index, {
			entry=unitEntry,
			type=unitType,
			plotID=-1
			});

		if(#prodQueue[cityID] == 1 or skipToFront) then
			BuildFirstQueued(city);
		else
			Refresh(true);
		end

	    UI.PlaySound("Confirm_Production");
	end

	--- ==========================================================================
	--  Adds unit to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueUnit(city, unitEntry, skipToFront)
		QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.UNIT, skipToFront);
	end

	--- ==========================================================================
	--  Adds corps to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueUnitCorps(city, unitEntry, skipToFront)
		QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.CORPS, skipToFront);
	end

	--- ==========================================================================
	--  Adds army to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueUnitArmy(city, unitEntry, skipToFront)
		QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.ARMY, skipToFront);
	end

	--- ==========================================================================
	--  Adds building to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueBuilding(city, buildingEntry, skipToFront)
		local building			:table		= GameInfo.Buildings[buildingEntry.Type];
		local bNeedsPlacement	:boolean	= building.RequiresPlacement;

		local pBuildQueue = city:GetBuildQueue();
		if (pBuildQueue:HasBeenPlaced(buildingEntry.Hash)) then
			bNeedsPlacement = false;
		end

		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

		if (bNeedsPlacement) then
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
		else
			local cityID = city:GetID();
			local plotID = -1;
			local buildingType = PRODUCTION_TYPE.BUILDING;

			if(not prodQueue[cityID]) then
				prodQueue[cityID] = {};
			end

			if(building.RequiresPlacement) then
				local pCityBuildings	:table = city:GetBuildings();
				local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( city );
				if (kCityPlots ~= nil) then
					for _,plot in pairs(kCityPlots) do
						local kPlot:table =  Map.GetPlotByIndex(plot);
						local wonderType = kPlot:GetWonderType();
						if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == building.BuildingType) then
							plotID = plot;
							buildingType = PRODUCTION_TYPE.PLACED;
						end
					end
				end
			end

			table.insert(prodQueue[cityID], {
				entry=buildingEntry,
				type=buildingType,
				plotID=plotID
				});

			if(skipToFront) then
				if(MoveQueueIndex(cityID, #prodQueue[cityID], 1) ~= 0) then
					Refresh(true);
				else
					BuildFirstQueued(city);
				end
			elseif(#prodQueue[cityID] == 1) then
				BuildFirstQueued(city);
			else
				Refresh(true);
			end

	        UI.PlaySound("Confirm_Production");
		end
	end

	--- ==========================================================================
	--  Adds district to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueDistrict(city, districtEntry, skipToFront)
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

		local district			:table		= GameInfo.Districts[districtEntry.Type];
		local bNeedsPlacement	:boolean	= district.RequiresPlacement;
		local pBuildQueue		:table		= city:GetBuildQueue();

		if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
			bNeedsPlacement = false;
		end

		if (bNeedsPlacement) then
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
		else
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;

			local cityID = city:GetID();

			if(not prodQueue[cityID]) then
				prodQueue[cityID] = {};
			end

			local index = 1;
			if(not skipToFront) then index = #prodQueue[cityID] + 1; end

			table.insert(prodQueue[cityID], index, {
				entry=districtEntry,
				type=PRODUCTION_TYPE.PLACED,
				plotID=-1,
				tParameters=tParameters
				});

			if(#prodQueue[cityID] == 1 or skipToFront) then
				BuildFirstQueued(city);
			else
				Refresh(true);
			end
	        UI.PlaySound("Confirm_Production");
		end
	end

	--- ==========================================================================
	--  Adds project to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueProject(city, projectEntry, skipToFront)
		local cityID = city:GetID();

		if(not prodQueue[cityID]) then
			prodQueue[cityID] = {};
		end

		local index = 1;
		if(not skipToFront) then index = #prodQueue[cityID] + 1; end

		table.insert(prodQueue[cityID], index, {
			entry=projectEntry,
			type=PRODUCTION_TYPE.PROJECT,
			plotID=-1
			});

		if(#prodQueue[cityID] == 1 or skipToFront) then
				BuildFirstQueued(city);
		else
			Refresh(true);
		end

	    UI.PlaySound("Confirm_Production");
	end

	--- ===========================================================================
	--	Check if removing an index would result in an empty queue
	--- ===========================================================================
	function CanRemoveFromQueue(cityID, index)
		local totalItemsToRemove = 1;

		if(prodQueue[cityID] and #prodQueue[cityID] > 1 and prodQueue[cityID][index]) then
			local destIndex = MoveQueueIndex(cityID, index, #prodQueue[cityID], true);
			if(destIndex > 0) then
				totalItemsToRemove = totalItemsToRemove + 1;
				CanRemoveFromQueue(cityID, destIndex + 1);
			end
		end

		if(totalItemsToRemove == #prodQueue[cityID]) then
			return false;
		else
			return true;
		end
	end

	--- ===========================================================================
	--	Remove a specific index from a city's Production Queue
	--- ===========================================================================
	function RemoveFromQueue(cityID, index, force)
		if(prodQueue[cityID] and (#prodQueue[cityID] > 1 or force) and prodQueue[cityID][index]) then
			local destIndex = MoveQueueIndex(cityID, index, #prodQueue[cityID]);
			if(destIndex > 0) then
				-- There was a conflict
				RemoveFromQueue(cityID, destIndex + 1);
				table.remove(prodQueue[cityID], destIndex);
			else
				table.remove(prodQueue[cityID], #prodQueue[cityID]);
			end
			return true;
		end
		return false;
	end

	--- ==========================================================================
	--  Directly requests the city to build a placed district/wonder using
	--  tParameters provided from the StrategicView callback event
	--- ==========================================================================
	function BuildPlaced(city, tParameters)
		-- Check if we still have enough population for a district we're about to place
		local districtHash = tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE];
		if(districtHash) then
			local pCityDistricts = city:GetDistricts();
			local numDistricts = pCityDistricts:GetNumZonedDistrictsRequiringPopulation();
			local numPossibleDistricts = pCityDistricts:GetNumAllowedDistrictsRequiringPopulation();

			if(GameInfo.Districts[districtHash] and GameInfo.Districts[districtHash].RequiresPopulation and numDistricts <= numPossibleDistricts) then
				if(GetNumDistrictsInCityQueue(city) + numDistricts > numPossibleDistricts) then
					RemoveFromQueue(city:GetID(), 1);
					BuildFirstQueued(city);
					return;
				end
			end
		end

		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	--- ==========================================================================
	--  Builds the first item in the Production Queue
	--- ==========================================================================
	function BuildFirstQueued(pCity)
		local cityID = pCity:GetID();
		if(prodQueue[cityID][1]) then
			if(prodQueue[cityID][1].type == PRODUCTION_TYPE.BUILDING) then
				BuildBuilding(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.UNIT) then
				BuildUnit(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.ARMY) then
				BuildUnitArmy(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.CORPS) then
				BuildUnitCorps(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.PLACED) then
				if(not prodQueue[cityID][1].tParameters) then
					if(GameInfo.Buildings[prodQueue[cityID][1].entry.Hash]) then
						BuildBuilding(pCity, prodQueue[cityID][1].entry);
					else
						ZoneDistrict(pCity, prodQueue[cityID][1].entry);
					end
				else
					BuildPlaced(pCity, prodQueue[cityID][1].tParameters);
				end
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.PROJECT) then
				AdvanceProject(pCity, prodQueue[cityID][1].entry);
			end
		else
			Refresh(true);
		end
	end

	--- ============================================================================
	--  Lua Event
	--  This is fired when a district or wonder plot has been selected and confirmed
	--- ============================================================================
	function OnStrategicViewMapPlacementProductionClose(tProductionQueueParameters)
		local cityID = tProductionQueueParameters.pSelectedCity:GetID();
		local entry = GetProductionInfoOfCity(tProductionQueueParameters.pSelectedCity, tProductionQueueParameters.buildingHash);
		entry.Hash = tProductionQueueParameters.buildingHash;

		if(not prodQueue[cityID]) then prodQueue[cityID] = {}; end

		local index = 1;
		if(not nextDistrictSkipToFront) then index = #prodQueue[cityID] + 1; end

		table.insert(prodQueue[cityID], index, {
			entry=entry,
			type=PRODUCTION_TYPE.PLACED,
			plotID=tProductionQueueParameters.plotId,
			tParameters=tProductionQueueParameters.tParameters
			});

		if(nextDistrictSkipToFront or #prodQueue[cityID] == 1) then BuildFirstQueued(tProductionQueueParameters.pSelectedCity); end
		Refresh(true);
		UI.PlaySound("Confirm_Production");
	end

	--- ===========================================================================
	--	Move a city's queue item from one index to another
	--- ===========================================================================
	function MoveQueueIndex(cityID, sourceIndex, destIndex, noMove)
		local direction = -1;
		local actualDest = 0;

		local sourceInfo = prodQueue[cityID][sourceIndex];

		if(sourceIndex < destIndex) then direction = 1; end
		for i=sourceIndex, math.max(destIndex-direction, 1), direction do
			-- Each time we swap, we need to check that there isn't a prereq that would break
			if(sourceInfo.type == PRODUCTION_TYPE.BUILDING and prodQueue[cityID][i+direction].type == PRODUCTION_TYPE.PLACED) then
				local buildingInfo = GameInfo.Buildings[sourceInfo.entry.Hash];
				if(buildingInfo and buildingInfo.PrereqDistrict) then
					local districtInfo = GameInfo.Districts[prodQueue[cityID][i+direction].entry.Hash];
					if(districtInfo and (districtInfo.DistrictType == buildingInfo.PrereqDistrict or (GameInfo.DistrictReplaces[prodQueue[cityID][i+direction].entry.Hash] and GameInfo.DistrictReplaces[prodQueue[cityID][i+direction].entry.Hash].ReplacesDistrictType == buildingInfo.PrereqDistrict))) then
						actualDest = i;
						break;
					end
				end
			elseif(sourceInfo.type == PRODUCTION_TYPE.PLACED and prodQueue[cityID][i+direction].type == PRODUCTION_TYPE.BUILDING) then
				local buildingInfo = GameInfo.Buildings[prodQueue[cityID][i+direction].entry.Hash];
				local districtInfo = GameInfo.Districts[sourceInfo.entry.Hash];

				if(buildingInfo and buildingInfo.PrereqDistrict) then
					if(districtInfo and (districtInfo.DistrictType == buildingInfo.PrereqDistrict or (GameInfo.DistrictReplaces[sourceInfo.entry.Hash] and GameInfo.DistrictReplaces[sourceInfo.entry.Hash].ReplacesDistrictType == buildingInfo.PrereqDistrict))) then
						actualDest = i;
						break;
					end
				end
			elseif(sourceInfo.type == PRODUCTION_TYPE.BUILDING and prodQueue[cityID][i+direction].type == PRODUCTION_TYPE.BUILDING) then
				local destInfo = GameInfo.Buildings[prodQueue[cityID][i+direction].entry.Hash];
				local sourceBuildingInfo = GameInfo.Buildings[sourceInfo.entry.Hash];

				if(GameInfo.BuildingReplaces[destInfo.BuildingType]) then
					destInfo = GameInfo.Buildings[GameInfo.BuildingReplaces[destInfo.BuildingType].ReplacesBuildingType];
				end

				if(GameInfo.BuildingReplaces[sourceBuildingInfo.BuildingType]) then
					sourceBuildingInfo = GameInfo.Buildings[GameInfo.BuildingReplaces[sourceBuildingInfo.BuildingType].ReplacesBuildingType];
				end

				local halt = false;

				for prereqRow in GameInfo.BuildingPrereqs() do
					if(prereqRow.Building == sourceBuildingInfo.BuildingType) then
						if(destInfo.BuildingType == prereqRow.PrereqBuilding) then
							halt = true;
							actualDest = i;
							break;
						end
					end

					if(prereqRow.PrereqBuilding == sourceBuildingInfo.BuildingType) then
						if(destInfo.BuildingType == prereqRow.Building) then
							halt = true;
							actualDest = i;
							break;
						end
					end
				end

				if(halt == true) then break; end
			end

			if(not noMove) then
				prodQueue[cityID][i], prodQueue[cityID][i+direction] = prodQueue[cityID][i+direction], prodQueue[cityID][i];
			end
		end

		return actualDest;
	end

	--- ===========================================================================
	--	Check the entire queue for mandatory item upgrades
	--- ===========================================================================
	function CheckAndReplaceAllQueuesForUpgrades()
		local localPlayerId:number = Game.GetLocalPlayer();
		local player = Players[localPlayerId];

		if(player == nil) then
			return;
		end

	 	local cities = player:GetCities();

	 	for j, city in cities:Members() do
	 		CheckAndReplaceQueueForUpgrades(city);
	 	end
	end

	--- ===========================================================================
	--	Check a city's queue for items that must be upgraded or removed
	--  as per tech/civic knowledge
	--- ===========================================================================
	function CheckAndReplaceQueueForUpgrades(city)
		local playerID = Game.GetLocalPlayer();
		local pPlayer = Players[playerID];
		local pTech = pPlayer:GetTechs();
		local pCulture = pPlayer:GetCulture();
		local buildQueue = city:GetBuildQueue();
		local cityID = city:GetID();
		local pBuildings = city:GetBuildings();
		local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
		local removeUnits = {};

		if(not prodQueue[cityID]) then prodQueue[cityID] = {} end

		for i, qi in pairs(prodQueue[cityID]) do
			if(qi.type == PRODUCTION_TYPE.UNIT or qi.type == PRODUCTION_TYPE.CORPS or qi.type == PRODUCTION_TYPE.ARMY) then
				local unitUpgrades = GameInfo.UnitUpgrades[qi.entry.Hash];
				if(unitUpgrades) then
					local upgradeUnit = GameInfo.Units[unitUpgrades.UpgradeUnit];

					-- Check for unique units
					for unitReplaces in GameInfo.UnitReplaces() do
						if(unitReplaces.ReplacesUnitType == unitUpgrades.UpgradeUnit) then
							local match = false;

							for civTraits in GameInfo.CivilizationTraits() do
								if(civTraits.TraitType == "TRAIT_CIVILIZATION_" .. unitReplaces.CivUniqueUnitType and civTraits.CivilizationType == civTypeName) then
									upgradeUnit = GameInfo.Units[unitReplaces.CivUniqueUnitType];
									match = true;
									break;
								end
							end

							if(match) then break; end
						end
					end

					if(upgradeUnit) then
						local canUpgrade = true;

						if(upgradeUnit.PrereqTech and not pTech:HasTech(GameInfo.Technologies[upgradeUnit.PrereqTech].Index)) then
							canUpgrade = false;
						end
						if(upgradeUnit.PrereqCivic and not pCulture:HasCivic(GameInfo.Civics[upgradeUnit.PrereqCivic].Index)) then
							canUpgrade = false;
						end

						local canBuildNewUnit = buildQueue:CanProduce( upgradeUnit.Hash, false, true );

						-- Only auto replace if we CAN'T queue the old unit
						if(not buildQueue:CanProduce( qi.entry.Hash, true ) and canUpgrade and canBuildNewUnit) then
							local isCanProduceExclusion, results	 = buildQueue:CanProduce( upgradeUnit.Hash, false, true );
							local isDisabled				:boolean = not isCanProduceExclusion;
							local sAllReasons				 :string = ComposeFailureReasonStrings( isDisabled, results );
							local sToolTip					 :string = ToolTipHelper.GetUnitToolTip( upgradeUnit.Hash ) .. sAllReasons;

							local nProductionCost		:number = buildQueue:GetUnitCost( upgradeUnit.Index );
							local nProductionProgress	:number = buildQueue:GetUnitProgress( upgradeUnit.Index );
							sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

							prodQueue[cityID][i].entry = {
								Type			= upgradeUnit.UnitType,
								Name			= upgradeUnit.Name,
								ToolTip			= sToolTip,
								Hash			= upgradeUnit.Hash,
								Kind			= upgradeUnit.Kind,
								TurnsLeft		= buildQueue:GetTurnsLeft( upgradeUnit.Hash ),
								Disabled		= isDisabled,
								Civilian		= upgradeUnit.FormationClass == "FORMATION_CLASS_CIVILIAN",
								Cost			= nProductionCost,
								Progress		= nProductionProgress,
								Corps			= false,
								CorpsCost		= 0,
								CorpsTurnsLeft	= 1,
								CorpsTooltip	= "",
								CorpsName		= "",
								Army			= false,
								ArmyCost		= 0,
								ArmyTurnsLeft	= 1,
								ArmyTooltip		= "",
								ArmyName		= ""
							};

							if results ~= nil then
								if results[CityOperationResults.CAN_TRAIN_CORPS] then
									kUnit.Corps			= true;
									kUnit.CorpsCost		= buildQueue:GetUnitCorpsCost( upgradeUnit.Index );
									kUnit.CorpsTurnsLeft	= buildQueue:GetTurnsLeft( upgradeUnit.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
									kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( upgradeUnit.Name, upgradeUnit.Domain, nProductionProgress, kUnit.CorpsCost );
								end
								if results[CityOperationResults.CAN_TRAIN_ARMY] then
									kUnit.Army			= true;
									kUnit.ArmyCost		= buildQueue:GetUnitArmyCost( upgradeUnit.Index );
									kUnit.ArmyTurnsLeft	= buildQueue:GetTurnsLeft( upgradeUnit.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
									kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( upgradeUnit.Name, upgradeUnit.Domain, nProductionProgress, kUnit.ArmyCost );
								end
							end
						elseif(canUpgrade and not canBuildNewUnit) then
							-- Can't build the old or new unit. Probably missing a resource. Remove from queue.
							table.insert(removeUnits, i);
						end
					end
				else
					local canBuildUnit = buildQueue:CanProduce( qi.entry.Hash, false, true );
					if(not canBuildUnit) then
						table.insert(removeUnits, i);
					end
				end
			elseif(qi.type == PRODUCTION_TYPE.BUILDING or qi.type == PRODUCTION_TYPE.PLACED) then
				if(qi.entry.Repair == true and GameInfo.Buildings[qi.entry.Hash]) then
					local isPillaged = pBuildings:IsPillaged(GameInfo.Buildings[qi.entry.Hash].Index);
					if(not isPillaged) then
						-- Repair complete, remove from queue
						table.insert(removeUnits, i);
					end
				end

				-- Check if a queued wonder is still available
				if(GameInfo.Buildings[qi.entry.Hash] and GameInfo.Buildings[qi.entry.Hash].MaxWorldInstances == 1) then
					if(not buildQueue:CanProduce(qi.entry.Hash, true)) then
						table.insert(removeUnits, i);
					elseif(not IsCityPlotValidForWonderPlacement(city, qi.plotID, GameInfo.Buildings[qi.entry.Hash]) and not buildQueue:HasBeenPlaced(qi.entry.Hash)) then
						table.insert(removeUnits, i);
					end
				end
			end
		end

		if(#removeUnits > 0) then
			for i=#removeUnits, 1, -1 do
				local success = RemoveFromQueue(cityID, removeUnits[i]);
				if(success and removeUnits[i] == 1) then
					BuildFirstQueued(city);
				end
			end
		end
	end

	function IsCityPlotValidForWonderPlacement(city, plotID, wonder)
		if(not plotID or plotID == -1) then return true end
		if Map.GetPlotByIndex(plotID):CanHaveWonder(wonder.Index, city:GetOwner(), city:GetID()) then
			return true;
		else
			return false;
		end
	end

	--- =======================================================================================================
	--  === UI handling
	--- =======================================================================================================

	--- ==========================================================================
	--  Resize the Production Queue window to fit the items
	--- ==========================================================================
	function ResizeQueueWindow()
		Controls.QueueWindow:SetSizeY(1);
		local windowHeight = math.min(math.max(#prodQueue[UI.GetHeadSelectedCity():GetID()] * 32 + 38, 70), screenHeight-300);
		Controls.QueueWindow:SetSizeY(windowHeight);
		Controls.ProductionQueueListScroll:SetSizeY(windowHeight-38);
		Controls.ProductionQueueListScroll:CalculateSize();
	end

	--- ==========================================================================
	--  Slide-in/hide the Production Queue panel
	--- ==========================================================================
	function CloseQueueWindow()
		Controls.QueueSlideIn:Reverse();
		Controls.QueueWindowToggleDirection:SetText("<");
	end

	--- ==========================================================================
	--  Slide-out/show the Production Queue panel
	--- ==========================================================================
	function OpenQueueWindow()
		Controls.QueueSlideIn:SetToBeginning();
		Controls.QueueSlideIn:Play();
		Controls.QueueWindowToggleDirection:SetText(">");
	end

	--- ==========================================================================
	--  Toggle the visibility of the Production Queue panel
	--- ==========================================================================
	function ToggleQueueWindow()
		showStandaloneQueueWindow = not showStandaloneQueueWindow;

		if(showStandaloneQueueWindow) then
			OpenQueueWindow();
		else
			CloseQueueWindow();
		end
	end

	--- ===============================================================================
	--  Control Event
	--  Fires when the production panel has finished fading in
	--  Use this to, if it is toggled off, delay showing the Production Queue panel
	--  (and therefore toggle tab) unitl after the production panel is there to
	--  cover it up
	--- ===============================================================================
	function OnPanelFadeInComplete()
		if(not showStandaloneQueueWindow) then
			Controls.QueueAlphaIn:Play();
		end
	end

	--- ===========================================================================
	--	Recenter the camera over the selected city
	--  This is here for the sake of middle mouse clicking on a production item
	--  which ordinarily recenters the map to the cursor position
	--- ===========================================================================
	function RecenterCameraToSelectedCity()
		local kCity:table = UI.GetHeadSelectedCity();
		UI.LookAtPlot( kCity:GetX(), kCity:GetY() );
	end

	function ResetSelectedCityQueue()
		local selectedCity = UI.GetHeadSelectedCity();
		if(not selectedCity) then return end

		local cityID = selectedCity:GetID();
		if(not cityID) then return end

		local buildQueue = selectedCity:GetBuildQueue();
		local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
		local plotID = -1;

		if(prodQueue[cityID]) then prodQueue[cityID] = {}; end

		if(currentProductionHash ~= 0) then
			-- Determine the type of the item
			local currentType = 0;
			local productionInfo = GetProductionInfoOfCity(selectedCity, currentProductionHash);
			productionInfo.Hash = currentProductionHash;

			if(productionInfo.Type == "UNIT") then
				currentType = buildQueue:GetCurrentProductionTypeModifier() + 2;
			elseif(productionInfo.Type == "BUILDING") then
				if(GameInfo.Buildings[currentProductionHash].MaxWorldInstances == 1) then
					currentType = PRODUCTION_TYPE.PLACED;

					local pCityBuildings	:table = selectedCity:GetBuildings();
					local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( selectedCity );
					if (kCityPlots ~= nil) then
						for _,plot in pairs(kCityPlots) do
							local kPlot:table =  Map.GetPlotByIndex(plot);
							local wonderType = kPlot:GetWonderType();
							if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == GameInfo.Buildings[currentProductionHash].BuildingType) then
								plotID = plot;
							end
						end
					end
				else
					currentType = PRODUCTION_TYPE.BUILDING;
				end
			elseif(productionInfo.Type == "DISTRICT") then
				currentType = PRODUCTION_TYPE.PLACED;
			elseif(productionInfo.Type == "PROJECT") then
				currentType = PRODUCTION_TYPE.PROJECT;
			end

			if(currentType == 0) then
				print("Could not find production type for hash: " .. currentProductionHash);
			end

			prodQueue[cityID][1] = {
				entry=productionInfo,
				type=currentType,
				plotID=plotID
			}
		end

		Refresh();
	end
	--- =========================================================================================================
	--- =========================================================================================================
	--- =========================================================================================================



	--- =========================================================================================================
	--  ============================================= MODULE INITIALIZATION =====================================
	--- =========================================================================================================
	function Initialize()
		LoadQueues();
		Controls.PauseCollapseList:Stop();
		Controls.PauseDismissWindow:Stop();
		CreateCorrectTabs();
		Resize();

		-- ===== Event listeners =====

		Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
		Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		Controls.PauseCollapseList:RegisterEndCallback( OnCollapseTheList );
		Controls.PauseDismissWindow:RegisterEndCallback( OnHide );
		Controls.QueueWindowToggle:RegisterCallback(Mouse.eLClick, ToggleQueueWindow);
		Controls.AlphaIn:RegisterEndCallback( OnPanelFadeInComplete )
		Controls.ProductionTabSelected:SetSpeed(100);
		Controls.QueueWindowReset:RegisterCallback(Mouse.eLClick, ResetSelectedCityQueue);

		ContextPtr:SetInitHandler( OnInit  );
		ContextPtr:SetInputHandler( OnInputHandler, true );
		ContextPtr:SetShutdown( OnShutdown );

		Events.CitySelectionChanged.Add( OnCitySelectionChanged );
		Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
		Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
		Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
		Events.PlayerTurnActivated.Add( OnPlayerTurnActivated );

		LuaEvents.CityBannerManager_ProductionToggle.Add( OnCityBannerManagerProductionToggle );
		LuaEvents.CityPanel_ChooseProduction.Add( OnCityPanelChooseProduction );
		LuaEvents.CityPanel_ChoosePurchase.Add( OnCityPanelChoosePurchase );
		LuaEvents.CityPanel_ProductionClose.Add( OnProductionClose );
		LuaEvents.CityPanel_ProductionOpen.Add( OnCityPanelProductionOpen );
		LuaEvents.CityPanel_PurchaseGoldOpen.Add( OnCityPanelPurchaseGoldOpen );
		LuaEvents.CityPanel_PurchaseFaithOpen.Add( OnCityPanelPurchaseFaithOpen );
		LuaEvents.CityPanel_ProductionOpenForQueue.Add( OnProductionOpenForQueue );
		LuaEvents.CityPanel_PurchasePlot.Add( OnCityPanelPurchasePlot );
		LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
		LuaEvents.NotificationPanel_ChooseProduction.Add( OnNotificationPanelChooseProduction );
		LuaEvents.StrageticView_MapPlacement_ProductionOpen.Add( OnStrategicViewMapPlacementProductionOpen );
		LuaEvents.StrageticView_MapPlacement_ProductionClose.Add( OnStrategicViewMapPlacementProductionClose );
		LuaEvents.Tutorial_ProductionOpen.Add( OnTutorialProductionOpen );

		Events.CityProductionChanged.Add( OnCityProductionChanged );
		Events.CityProductionCompleted.Add(OnCityProductionCompleted);
		Events.CityProductionUpdated.Add(OnCityProductionUpdated);
		Events.CityMadePurchase.Add(Refresh);
	end
	Initialize();
else
	-- Does not have the Rise and Fall update
	-- ===========================================================================
	--	Production Panel / Purchase Panel
	-- ===========================================================================

	include( "ToolTipHelper" );
	include( "InstanceManager" );
	include( "TabSupport" );
	include( "Civ6Common" );
	include( "SupportFunctions" );
	include( "AdjacencyBonusSupport");
	include( "DragSupport" );
	include( "CitySupport" );

	-- ===========================================================================
	--	Constants
	-- ===========================================================================
	local RELOAD_CACHE_ID	:string = "ProductionPanel";
	local COLOR_LOW_OPACITY	:number = 0x3fffffff;
	local HEADER_Y			:number	= 41;
	local WINDOW_HEADER_Y	:number	= 150;
	local TOPBAR_Y			:number	= 28;
	local SEPARATOR_Y		:number	= 20;
	local BUTTON_Y			:number	= 48;
	local DISABLED_PADDING_Y:number	= 10;
	local TEXTURE_BASE				:string = "UnitFlagBase";
	local TEXTURE_CIVILIAN			:string = "UnitFlagCivilian";
	local TEXTURE_RELIGION			:string = "UnitFlagReligion";
	local TEXTURE_EMBARK			:string = "UnitFlagEmbark";
	local TEXTURE_FORTIFY			:string = "UnitFlagFortify";
	local TEXTURE_NAVAL				:string = "UnitFlagNaval";
	local TEXTURE_SUPPORT			:string = "UnitFlagSupport";
	local TEXTURE_TRADE				:string = "UnitFlagTrade";
	local BUILDING_IM_PREFIX		:string = "buildingListingIM_";
	local BUILDING_DRAWER_PREFIX	:string = "buildingDrawer_";
	local ICON_PREFIX				:string = "ICON_";
	local LISTMODE					:table	= {PRODUCTION = 1, PURCHASE_GOLD = 2, PURCHASE_FAITH=3};
	local EXTENDED_BUTTON_HEIGHT = 60;
	local DEFAULT_BUTTON_HEIGHT = 48;
	local DROP_OVERLAP_REQUIRED		:number = 0.5;
	local PRODUCTION_TYPE :table = {
			BUILDING	= 1,
			UNIT		= 2,
			CORPS		= 3,
			ARMY		= 4,
			PLACED		= 5,
			PROJECT		= 6
	};

	-- ===========================================================================
	--	Members
	-- ===========================================================================

	local m_queueIM			= InstanceManager:new( "UnnestedList",  "Top", Controls.ProductionQueueList );
	local m_listIM			= InstanceManager:new( "NestedList",  "Top", Controls.ProductionList );
	local m_purchaseListIM	= InstanceManager:new( "NestedList",  "Top", Controls.PurchaseList );
	local m_purchaseFaithListIM	= InstanceManager:new( "NestedList",  "Top", Controls.PurchaseFaithList );

	local m_tabs;
	local m_productionTab;	-- Additional tracking of the tab control data so that we can select between graphical tabs and label tabs
	local m_purchaseTab;
	local m_faithTab;
	local m_maxProductionSize	:number	= 0;
	local m_maxPurchaseSize		:number	= 0;
	local m_isQueueMode			:boolean = false;
	local m_TypeNames			:table	= {};
	local m_kClickedInstance;
	local m_isCONTROLpressed	:boolean = false;
	local prodBuildingList;
	local prodWonderList;
	local prodUnitList;
	local prodDistrictList;
	local prodProjectList;
	local purchBuildingList;
	local purchGoldBuildingList;
	local purchFaithBuildingList;
	local purchUnitList;
	local purchGoldUnitList
	local purchFaithUnitList

	local showDisabled :boolean = true;
	local m_recommendedItems:table;

	-- Production Queue
	local nextDistrictSkipToFront = false;
	local showStandaloneQueueWindow = true;
	local _, screenHeight = UIManager:GetScreenSizeVal();
	local quickRefresh = true;
	local m_kProductionQueueDropAreas = {}; -- Required by drag and drop system
	local lastProductionCompletePerCity = {};
	local buildingPrereqs = {};
	local mutuallyExclusiveBuildings = {};
	hstructure DropAreaStruct -- Lua based struct (required copy from DragSupport)
		x		: number
		y		: number
		width	: number
		height	: number
		control	: table
		id		: number	-- (optional, extra info/ID)
	end

	------------------------------------------------------------------------------
	-- Collapsible List Handling
	------------------------------------------------------------------------------
	function OnCollapseTheList()
		m_kClickedInstance.List:SetHide(true);
		m_kClickedInstance.ListSlide:SetSizeY(0);
		m_kClickedInstance.ListAlpha:SetSizeY(0);
		Controls.PauseCollapseList:SetToBeginning();
		m_kClickedInstance.ListSlide:SetToBeginning();
		m_kClickedInstance.ListAlpha:SetToBeginning();
		Controls.ProductionList:CalculateSize();
		Controls.PurchaseList:CalculateSize();
		Controls.ProductionList:ReprocessAnchoring();
		Controls.PurchaseList:ReprocessAnchoring();
		Controls.ProductionListScroll:CalculateInternalSize();
		Controls.PurchaseListScroll:CalculateInternalSize();
	end

	-- ===========================================================================
	function OnCollapse(instance:table)
		m_kClickedInstance = instance;
		instance.ListSlide:Reverse();
		instance.ListAlpha:Reverse();
		instance.ListSlide:SetSpeed(15.0);
		instance.ListAlpha:SetSpeed(15.0);
		instance.ListSlide:Play();
		instance.ListAlpha:Play();
		instance.HeaderOn:SetHide(true);
		instance.Header:SetHide(false);
		Controls.PauseCollapseList:Play();	--By doing this we can delay collapsing the list until the "out" sequence has finished playing
	end

	-- ===========================================================================
	function OnExpand(instance:table)
		if(quickRefresh) then
			instance.ListSlide:SetSpeed(100);
			instance.ListAlpha:SetSpeed(100);
		else
			instance.ListSlide:SetSpeed(3.5);
			instance.ListAlpha:SetSpeed(4);
		end
		m_kClickedInstance = instance;
		instance.HeaderOn:SetHide(false);
		instance.Header:SetHide(true);
		instance.List:SetHide(false);
		instance.ListSlide:SetSizeY(instance.List:GetSizeY());
		instance.ListAlpha:SetSizeY(instance.List:GetSizeY());
		instance.ListSlide:SetToBeginning();
		instance.ListAlpha:SetToBeginning();
		instance.ListSlide:Play();
		instance.ListAlpha:Play();
		Controls.ProductionList:CalculateSize();
		Controls.PurchaseList:CalculateSize();
		Controls.ProductionList:ReprocessAnchoring();
		Controls.PurchaseList:ReprocessAnchoring();
		Controls.ProductionListScroll:CalculateInternalSize();
		Controls.PurchaseListScroll:CalculateInternalSize();
	end

	-- ===========================================================================
	function OnTabChangeProduction()
		Controls.MiniProductionTab:SetSelected(true);
		Controls.MiniPurchaseTab:SetSelected(false);
		Controls.MiniPurchaseFaithTab:SetSelected(false);
		Controls.PurchaseFaithMenu:SetHide(true);
	    Controls.PurchaseMenu:SetHide(true);
	    Controls.ChooseProductionMenu:SetHide(false);
	    if (Controls.SlideIn:IsStopped()) then
			UI.PlaySound("Production_Panel_ButtonClick");
	        UI.PlaySound("Production_Panel_Open");
	    end
	end

	-- ===========================================================================
	function OnTabChangePurchase()
		Controls.MiniProductionTab:SetSelected(false);
		Controls.MiniPurchaseTab:SetSelected(true);
		Controls.MiniPurchaseFaithTab:SetSelected(false);
		Controls.ChooseProductionMenu:SetHide(true);
		Controls.PurchaseFaithMenu:SetHide(true);
		Controls.PurchaseMenu:SetHide(false);
		UI.PlaySound("Production_Panel_ButtonClick");
	end

	-- ===========================================================================
	function OnTabChangePurchaseFaith()
		Controls.MiniProductionTab:SetSelected(false);
		Controls.MiniPurchaseTab:SetSelected(false);
		Controls.MiniPurchaseFaithTab:SetSelected(true);
		Controls.ChooseProductionMenu:SetHide(true);
		Controls.PurchaseMenu:SetHide(true);
		Controls.PurchaseFaithMenu:SetHide(false);
		UI.PlaySound("Production_Panel_ButtonClick");
	end

	-- ===========================================================================
	-- Placement/Selection
	-- ===========================================================================
	function BuildUnit(city, unitEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function BuildUnitCorps(city, unitEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		tParameters[CityOperationTypes.MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function BuildUnitArmy(city, unitEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		tParameters[CityOperationTypes.MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function BuildBuilding(city, buildingEntry)
		local building			:table		= GameInfo.Buildings[buildingEntry.Hash];
		local bNeedsPlacement	:boolean	= building.RequiresPlacement;

		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

		local pBuildQueue = city:GetBuildQueue();
		if (pBuildQueue:HasBeenPlaced(buildingEntry.Hash)) then
			bNeedsPlacement = false;
		end

		-- If it's a Wonder and the city already has the building then it doesn't need to be replaced.
		if (bNeedsPlacement) then
			local cityBuildings = city:GetBuildings();
			if (cityBuildings:HasBuilding(buildingEntry.Hash)) then
				bNeedsPlacement = false;
			end
		end

		if(not pBuildQueue:CanProduce(buildingEntry.Hash, true)) then
			-- For one reason or another we can't produce this, so remove it
			RemoveFromQueue(city:GetID(), 1, true);
			BuildFirstQueued(city);
			return;
		end

		if ( bNeedsPlacement ) then
			-- If so, set the placement mode
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
		else
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
		end
	end

	-- ===========================================================================
	function ZoneDistrict(city, districtEntry)

		local district			:table		= GameInfo.Districts[districtEntry.Hash];
		local bNeedsPlacement	:boolean	= district.RequiresPlacement;
		local pBuildQueue		:table		= city:GetBuildQueue();

		if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
			bNeedsPlacement = false;
		end

		-- Almost all districts need to be placed, but just in case let's check anyway
		if (bNeedsPlacement ) then
			-- If so, set the placement mode
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
		else
			-- If not, add it to the queue.
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	        UI.PlaySound("Confirm_Production");
		end
	end

	-- ===========================================================================
	function AdvanceProject(city, projectEntry)
		local tParameters = {};
		tParameters[CityOperationTypes.PARAM_PROJECT_TYPE] = projectEntry.Hash;
		tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	-- ===========================================================================
	function PurchaseUnit(city, unitEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.STANDARD_MILITARY_FORMATION;
		if (unitEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseUnitCorps(city, unitEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.CORPS_MILITARY_FORMATION;
		if (unitEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseUnitArmy(city, unitEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = unitEntry.Hash;
		tParameters[CityCommandTypes.PARAM_MILITARY_FORMATION_TYPE] = MilitaryFormationTypes.ARMY_MILITARY_FORMATION;
		if (unitEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseBuilding(city, buildingEntry)
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
		if (buildingEntry.Yield == "YIELD_GOLD") then
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.PlaySound("Purchase_With_Gold");
		else
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_FAITH"].Index;
			UI.PlaySound("Purchase_With_Faith");
		end
		CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	end

	-- ===========================================================================
	function PurchaseDistrict(city, districtEntry)
		local district			:table		= GameInfo.Districts[districtEntry.Type];
		local bNeedsPlacement	:boolean	= district.RequiresPlacement;
		local pBuildQueue		:table		= city:GetBuildQueue();

		if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
			bNeedsPlacement = false;
		end

		-- Almost all districts need to be placed, but just in case let's check anyway
		if (bNeedsPlacement ) then
			-- If so, set the placement mode
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
		else
			-- If not, add it to the queue.
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = GameInfo.Yields["YIELD_GOLD"].Index;
			CityManager.RequestCommand(city, CityCommandTypes.PURCHASE, tParameters);
	        UI.PlaySound("Purchase_With_Gold");
		end
	end

	-- ===========================================================================
	--	GAME Event
	--	City was selected.
	-- ===========================================================================
	function OnCitySelectionChanged( owner:number, cityID:number, i, j, k, isSelected:boolean, isEditable:boolean)
		local localPlayerId:number = Game.GetLocalPlayer();
		if owner == localPlayerId and isSelected then
			-- Already open then populate with newly selected city's data...
			if (ContextPtr:IsHidden() == false) and Controls.PauseDismissWindow:IsStopped() and Controls.AlphaIn:IsStopped() then
				Refresh();
			end
		end
	end

	-- ===========================================================================
	--	GAME Event
	--	eOldMode, mode the engine was formally in
	--	eNewMode, new mode the engine has just changed to
	-- ===========================================================================
	function OnInterfaceModeChanged( eOldMode:number, eNewMode:number )
		-- If this is raised while the city panel is up; selecting to purchase a
		-- plot or manage citizens will close it.
		if eNewMode == InterfaceModeTypes.CITY_MANAGEMENT or eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
			if not ContextPtr:IsHidden() then
				Close();
			end
		end
	end

	-- ===========================================================================
	--	GAME Event
	--	Unit was selected (impossible for a production panel to be up; close it
	-- ===========================================================================
	function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean )
		local localPlayer = Game.GetLocalPlayer();
		if playerID == localPlayer then
			-- If a unit is selected and this is showing; hide it.
			local pSelectedUnit:table = UI.GetHeadSelectedUnit();
			if pSelectedUnit ~= nil and not ContextPtr:IsHidden() then
				OnHide();
			end
		end
	end

	-- ===========================================================================
	--	Actual closing function, may have been called via click, keyboard input,
	--	or an external system call.
	-- ===========================================================================
	function Close()
		if (Controls.SlideIn:IsStopped()) then			-- Need to check to make sure that we have not already begun the transition before attempting to close the panel.
			UI.PlaySound("Production_Panel_Closed");
			Controls.SlideIn:Reverse();
			Controls.AlphaIn:Reverse();

			if(showStandaloneQueueWindow) then
				Controls.QueueSlideIn:Reverse();
				Controls.QueueAlphaIn:Reverse();
			else
				Controls.QueueAlphaIn:SetAlpha(0);
			end

			Controls.PauseDismissWindow:Play();
			LuaEvents.ProductionPanel_Close();
		end
	end

	-- ===========================================================================
	--	Close via click
	function OnClose()
		Close();
	end

	-- ===========================================================================
	--	Open the panel
	-- ===========================================================================
	function Open()
		if ContextPtr:IsHidden() then					-- The ContextPtr is only hidden as a callback to the finished SlideIn animation, so this check should be sufficient to ensure that we are not animating.
			-- Sets up proper selection AND the associated lens so it's not stuck "on".
			UI.PlaySound("Production_Panel_Open");
			LuaEvents.ProductionPanel_Open();
			UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
			Refresh();
			ContextPtr:SetHide(false);
			Controls.ProductionListScroll:SetScrollValue(0);

			-- Size the panel to the maximum Y value of the expanded content
			Controls.AlphaIn:SetToBeginning();
			Controls.SlideIn:SetToBeginning();
			Controls.AlphaIn:Play();
			Controls.SlideIn:Play();

			if(showStandaloneQueueWindow) then
				Controls.QueueAlphaIn:SetToBeginning();
				Controls.QueueSlideIn:SetToBeginning();
				Controls.QueueAlphaIn:Play();
				Controls.QueueSlideIn:Play();
				ResizeQueueWindow();
			end
		end
	end

	-- ===========================================================================
	function OnHide()
		ContextPtr:SetHide(true);
		Controls.PauseDismissWindow:SetToBeginning();
	end


	-- ===========================================================================
	--	Initialize, Refresh, Populate, View
	--	Update the layout based on the view model
	-- ===========================================================================
	function View(data, persistCollapse)
		local selectedCity	= UI.GetHeadSelectedCity();
		-- Get the hashes for the top three recommended items
		m_recommendedItems = selectedCity:GetCityAI():GetBuildRecommendations();
		PopulateList(data, LISTMODE.PRODUCTION, m_listIM);
		PopulateList(data, LISTMODE.PURCHASE_GOLD, m_purchaseListIM);
		PopulateList(data, LISTMODE.PURCHASE_FAITH, m_purchaseFaithListIM);

		if(persistCollapse) then
			if(prodDistrictList ~= nil and not prodDistrictList.HeaderOn:IsHidden()) then
				OnExpand(prodDistrictList);
			end
			if(prodWonderList ~= nil and not prodWonderList.HeaderOn:IsHidden()) then
				OnExpand(prodWonderList);
			end
			if(prodUnitList ~= nil and not prodUnitList.HeaderOn:IsHidden()) then
				OnExpand(prodUnitList);
			end
			if(prodProjectList ~= nil and not prodProjectList.HeaderOn:IsHidden()) then
				OnExpand(prodProjectList);
			end
			if(purchFaithBuildingList ~= nil and not purchFaithBuildingList.HeaderOn:IsHidden()) then
				OnExpand(purchFaithBuildingList);
			end
			if(purchGoldBuildingList ~= nil and not purchGoldBuildingList.HeaderOn:IsHidden()) then
				OnExpand(purchGoldBuildingList);
			end
			if(purchFaithUnitList ~= nil and not purchFaithUnitList.HeaderOn:IsHidden()) then
				OnExpand(purchFaithUnitList);
			end
			if(purchGoldUnitList ~= nil and not purchGoldUnitList.HeaderOn:IsHidden()) then
				OnExpand(purchGoldUnitList);
			end
		else
			if(prodDistrictList ~= nil) then
				OnExpand(prodDistrictList);
			end
			if(prodWonderList ~= nil) then
				OnExpand(prodWonderList);
			end
			if(prodUnitList ~= nil) then
				OnExpand(prodUnitList);
			end
			if(prodProjectList ~= nil) then
				OnExpand(prodProjectList);
			end
			if(purchFaithBuildingList ~= nil) then
				OnExpand(purchFaithBuildingList);
			end
			if(purchGoldBuildingList ~= nil) then
				OnExpand(purchGoldBuildingList);
			end
			if(purchFaithUnitList ~= nil ) then
				OnExpand(purchFaithUnitList);
			end
			if(purchGoldUnitList ~= nil) then
				OnExpand(purchGoldUnitList);
			end

			m_tabs.SelectTab(m_productionTab);
		end


		--

		if( Controls.PurchaseList:GetSizeY() == 0 ) then
			Controls.NoGoldContent:SetHide(false);
		else
			Controls.NoGoldContent:SetHide(true);
		end
		if( Controls.PurchaseFaithList:GetSizeY() == 0 ) then
			Controls.NoFaithContent:SetHide(false);
		else
			Controls.NoFaithContent:SetHide(true);
		end
	end

	function ResetInstanceVisibility(productionItem: table)
		if (productionItem.ArmyCorpsDrawer ~= nil) then
			productionItem.ArmyCorpsDrawer:SetHide(true);
			productionItem.CorpsArmyArrow:SetSelected(true);
			productionItem.CorpsRecommendedIcon:SetHide(true);
			productionItem.CorpsButtonContainer:SetHide(true);
			productionItem.CorpsDisabled:SetHide(true);
			productionItem.ArmyRecommendedIcon:SetHide(true);
			productionItem.ArmyButtonContainer:SetHide(true);
			productionItem.ArmyDisabled:SetHide(true);
			productionItem.CorpsArmyDropdownArea:SetHide(true);
		end
		if (productionItem.BuildingDrawer ~= nil) then
			productionItem.BuildingDrawer:SetHide(true);
			productionItem.CompletedArea:SetHide(true);
		end
		productionItem.RecommendedIcon:SetHide(true);
		productionItem.Disabled:SetHide(true);
	end
	-- ===========================================================================

	function PopulateList(data, listMode, listIM)
		listIM:ResetInstances();
		local districtList;
		local buildingList;
		local wonderList;
		local projectList;
		local unitList;
		local queueList;
		Controls.PauseCollapseList:Stop();
		local selectedCity	= UI.GetHeadSelectedCity();
		local pBuildings = selectedCity:GetBuildings();
		local cityID = selectedCity:GetID();
		local cityData = GetCityData(selectedCity);
		local localPlayer = Players[Game.GetLocalPlayer()];

		if(listMode == LISTMODE.PRODUCTION) then
			m_maxProductionSize = 0;
			-- Populate Current Item
			local buildQueue	= selectedCity:GetBuildQueue();
			local productionHash = 0;
			local completedStr = "";
			local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
			local previousProductionHash = buildQueue:GetPreviousProductionTypeHash();
			local screenX, screenY:number = UIManager:GetScreenSizeVal()

			if( currentProductionHash == 0 and previousProductionHash == 0 ) then
				Controls.CurrentProductionArea:SetHide(true);
				Controls.ProductionListScroll:SetSizeY(screenY-120);
				Controls.ProductionListScroll:CalculateSize();
				Controls.ProductionListScroll:SetOffsetY(10);

				completedStr = "";
			else
				Controls.CurrentProductionArea:SetHide(false);
				Controls.ProductionListScroll:SetSizeY(screenY-175);
				Controls.ProductionListScroll:CalculateSize();
				Controls.ProductionListScroll:SetOffsetY(65);

				if( currentProductionHash == 0 ) then
					productionHash = previousProductionHash;
					Controls.CompletedArea:SetHide(false);
					completedStr = Locale.ToUpper(Locale.Lookup("LOC_TECH_KEY_COMPLETED"));
				else
					Controls.CompletedArea:SetHide(true);
					productionHash = currentProductionHash;
					completedStr = ""
				end
			end

			local currentProductionInfo				:table = GetProductionInfoOfCity( data.City, productionHash );

			if (currentProductionInfo.Icon ~= nil) then
				Controls.CurrentProductionName:SetText(Locale.ToUpper(Locale.Lookup(currentProductionInfo.Name)).." "..completedStr);
				Controls.CurrentProductionProgress:SetPercent(currentProductionInfo.PercentComplete);
				Controls.CurrentProductionProgress:SetShadowPercent(currentProductionInfo.PercentCompleteNextTurn);
				Controls.CurrentProductionIcon:SetIcon(currentProductionInfo.Icon);
				if(currentProductionInfo.Description ~= nil) then
					Controls.CurrentProductionIcon:SetToolTipString(Locale.Lookup(currentProductionInfo.Description));
				else
					Controls.CurrentProductionIcon:SetToolTipString();
				end
				local numberOfTurns = currentProductionInfo.Turns;
				if numberOfTurns == -1 then
					numberOfTurns = "999+";
				end;

				Controls.CurrentProductionCost:SetText("[ICON_Turn]".. numberOfTurns);
				Controls.CurrentProductionProgressString:SetText("[ICON_ProductionLarge]"..currentProductionInfo.Progress.."/"..currentProductionInfo.Cost);
			end

			-- Populate Districts ------------------------ CANNOT purchase districts
			districtList = listIM:GetInstance();
			districtList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS_BUILDINGS")));
			districtList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS_BUILDINGS")));
			local dL = districtList;	-- Due to lambda capture, we need to copy this for callback
			if ( districtList.districtListIM ~= nil ) then
				districtList.districtListIM:ResetInstances();
			else
				districtList.districtListIM = InstanceManager:new( "DistrictListInstance", "Root", districtList.List);
			end

			-- In the interest of performance, we're keeping the instances that we created and resetting the data.
			-- This requires a little bit of footwork to remember the instances that have been modified and to manually reset them.
			for _,type in ipairs(m_TypeNames) do
				if ( districtList[BUILDING_IM_PREFIX..type] ~= nil) then		--Reset the states for the building instance managers
					districtList[BUILDING_IM_PREFIX..type]:ResetInstances();
				end
				if ( districtList[BUILDING_DRAWER_PREFIX..type] ~= nil) then	--Reset the states of the drawers
					districtList[BUILDING_DRAWER_PREFIX..type]:SetHide(true);
				end
			end

			for i, item in ipairs(data.DistrictItems) do
				if(GameInfo.Districts[item.Hash].RequiresPopulation and cityData.DistrictsNum < cityData.DistrictsPossibleNum) then
					if(GetNumDistrictsInCityQueue(selectedCity) + cityData.DistrictsNum >= cityData.DistrictsPossibleNum) then
						item.Disabled = true;
						if(not string.find(item.ToolTip, "COLOR:Red")) then
							item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_DISTRICT_ZONE_POPULATION_TOO_LOW_SHORT", cityData.DistrictsPossibleNum * 3 + 1);
						end
					end
				end

				local districtListing = districtList["districtListIM"]:GetInstance();
				ResetInstanceVisibility(districtListing);
				-- Check to see if this district item is one of the items that is recommended:
				for _,hash in ipairs( m_recommendedItems) do
					if(item.Hash == hash.BuildItemHash) then
						districtListing.RecommendedIcon:SetHide(false);
					end
				end

				local nameStr = Locale.Lookup("{1_Name}", item.Name);
				if (item.Repair) then
					nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
				end
				if (item.Contaminated) then
					nameStr = nameStr .. Locale.Lookup("LOC_PRODUCTION_ITEM_DECONTAMINATE");
				end
				districtListing.LabelText:SetText(nameStr);

				local turnsStrTT:string = "";
				local turnsStr:string = "";

				if(item.HasBeenBuilt and GameInfo.Districts[item.Type].OnePerCity == true and not item.Repair and not item.Contaminated and item.Progress == 0 and not item.TurnsLeft) then
					turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
					turnsStr = "[ICON_Checkmark]";
					districtListing.RecommendedIcon:SetHide(true);
				else
					if(item.TurnsLeft) then
						local numberOfTurns = item.TurnsLeft;
						if numberOfTurns == -1 then
							numberOfTurns = "999+";
							turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
						else
							turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
						end
						turnsStr = numberOfTurns .. "[ICON_Turn]";
					else
						turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
						turnsStr = "[ICON_Checkmark]";
						districtListing.RecommendedIcon:SetHide(true);
					end
				end

				if (item.Disabled) then
					if(item.HasBeenBuilt and GameInfo.Districts[item.Type].OnePerCity == true) then
						turnsStrTT = Locale.Lookup("LOC_HUD_CITY_DISTRICT_BUILT_TT");
						turnsStr = "[ICON_Checkmark]";
					end
				end

				if(item.Progress > 0) then
					districtListing.ProductionProgressArea:SetHide(false);
					local districtProgress = item.Progress/item.Cost;
					if (districtProgress < 1) then
						districtListing.ProductionProgress:SetPercent(districtProgress);
					else
						districtListing.ProductionProgressArea:SetHide(true);
					end
				else
					districtListing.ProductionProgressArea:SetHide(true);
				end

				districtListing.CostText:SetToolTipString(turnsStrTT);
				districtListing.CostText:SetText(turnsStr);
				districtListing.Button:SetToolTipString(item.ToolTip);
				districtListing.Disabled:SetToolTipString(item.ToolTip);
				districtListing.Icon:SetIcon(ICON_PREFIX..item.Type);

				local districtType = item.Type;
				-- Check to see if this is a unique district that will be substituted for another kind of district
				if(GameInfo.DistrictReplaces[item.Type] ~= nil) then
					districtType = 	GameInfo.DistrictReplaces[item.Type].ReplacesDistrictType;
				end
				local uniqueBuildingIMName = BUILDING_IM_PREFIX..districtType;
				local uniqueBuildingAreaName = BUILDING_DRAWER_PREFIX..districtType;

				table.insert(m_TypeNames, districtType);
				districtList[uniqueBuildingIMName] = InstanceManager:new( "BuildingListInstance", "Root", districtListing.BuildingStack);
				districtList[uniqueBuildingAreaName] = districtListing.BuildingDrawer;
				districtListing.CompletedArea:SetHide(true);

				if (item.Disabled) then
					if(item.HasBeenBuilt and GameInfo.Districts[item.Type].OnePerCity == true) then
						districtListing.CompletedArea:SetHide(false);
						districtListing.Disabled:SetHide(true);
					else
						if(showDisabled) then
							districtListing.Disabled:SetHide(false);
							districtListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							districtListing.Root:SetHide(true);
						end
					end
				else
					districtListing.Root:SetHide(false);
					districtListing.Disabled:SetHide(true);
					districtListing.Button:SetColor(0xFFFFFFFF);
				end
				districtListing.Button:SetDisabled(item.Disabled);
				districtListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				districtListing.Button:RegisterCallback( Mouse.eLClick, function()
					if(m_isCONTROLpressed) then
						nextDistrictSkipToFront = true;
					else
						nextDistrictSkipToFront = false;
					end

					QueueDistrict(data.City, item, nextDistrictSkipToFront);
				end);

				districtListing.Button:RegisterCallback( Mouse.eMClick, function()
					nextDistrictSkipToFront = true;
					QueueDistrict(data.City, item, true);
					RecenterCameraToSelectedCity();
				end);

				if(not IsTutorialRunning()) then
					districtListing.Button:RegisterCallback( Mouse.eRClick, function()
						LuaEvents.OpenCivilopedia(item.Type);
					end);
				end

				districtListing.Root:SetTag(UITutorialManager:GetHash(item.Type));
			end

			districtList.List:CalculateSize();
			districtList.List:ReprocessAnchoring();

			if (districtList.List:GetSizeY()==0) then
				districtList.Top:SetHide(true);
			else
				m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
				districtList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(dL);
					end);
				districtList.Header:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				districtList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(dL);
					end);
				districtList.HeaderOn:RegisterCallback(	Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
			end

			prodDistrictList = dL;

			-- Populate Nested Buildings -----------------
			for i, buildingItem in ipairs(data.BuildingItems) do
				local displayItem = true;

				-- PQ: Check if this building is mutually exclusive with another
				if(mutuallyExclusiveBuildings[buildingItem.Type]) then
					for mutuallyExclusiveBuilding in GameInfo.MutuallyExclusiveBuildings() do
						if mutuallyExclusiveBuilding.Building == buildingItem.Type then
							if(IsBuildingInQueue(selectedCity, GameInfo.Buildings[mutuallyExclusiveBuilding.MutuallyExclusiveBuilding].Hash) or pBuildings:HasBuilding(GameInfo.Buildings[mutuallyExclusiveBuilding.MutuallyExclusiveBuilding].Index)) then
								displayItem = false;
								-- -- Concatenanting two fragments is not loc friendly.  This needs to change.
								-- buildingItem.ToolTip = buildingItem.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_UI_PEDIA_EXCLUSIVE_WITH");
								-- buildingItem.ToolTip = buildingItem.ToolTip .. " " .. Locale.Lookup(GameInfo.Buildings[GameInfo.MutuallyExclusiveBuildings[buildingItem.Hash].MutuallyExclusiveBuilding].Name);
							end
						end
					end
				end

				if(buildingItem.Hash == GameInfo.Buildings["BUILDING_PALACE"].Hash) then
					displayItem = false;
				end

				if(not buildingItem.IsWonder and not IsBuildingInQueue(selectedCity, buildingItem.Hash) and displayItem) then
					local uniqueDrawerName = BUILDING_DRAWER_PREFIX..buildingItem.PrereqDistrict;
					local uniqueIMName = BUILDING_IM_PREFIX..buildingItem.PrereqDistrict;
					if (districtList[uniqueIMName] ~= nil) then
						local buildingListing = districtList[uniqueIMName]:GetInstance();
						ResetInstanceVisibility(buildingListing);
						-- Check to see if this is one of the recommended items
						for _,hash in ipairs( m_recommendedItems) do
							if(buildingItem.Hash == hash.BuildItemHash) then
								buildingListing.RecommendedIcon:SetHide(false);
							end
						end
						buildingListing.Root:SetSizeX(305);
						buildingListing.Button:SetSizeX(305);
						local districtBuildingAreaControl = districtList[uniqueDrawerName];
						districtBuildingAreaControl:SetHide(false);

						--Fill the meter if there is any progress, hide it if not
						if(buildingItem.Progress > 0) then
							buildingListing.ProductionProgressArea:SetHide(false);
							local buildingProgress = buildingItem.Progress/buildingItem.Cost;
							if (buildingProgress < 1) then
								buildingListing.ProductionProgress:SetPercent(buildingProgress);
							else
								buildingListing.ProductionProgressArea:SetHide(true);
							end
						else
							buildingListing.ProductionProgressArea:SetHide(true);
						end

						local nameStr = Locale.Lookup("{1_Name}", buildingItem.Name);
						if (buildingItem.Repair) then
							nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
						end
						buildingListing.LabelText:SetText(nameStr);
						local turnsStrTT:string = "";
						local turnsStr:string = "";
						local numberOfTurns = buildingItem.TurnsLeft;
						if numberOfTurns == -1 then
							numberOfTurns = "999+";
							turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
						else
							turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", buildingItem.TurnsLeft);
						end
						turnsStr = numberOfTurns .. "[ICON_Turn]";
						buildingListing.CostText:SetToolTipString(turnsStrTT);
						buildingListing.CostText:SetText(turnsStr);
						buildingListing.Button:SetToolTipString(buildingItem.ToolTip);
						buildingListing.Disabled:SetToolTipString(buildingItem.ToolTip);
						buildingListing.Icon:SetIcon(ICON_PREFIX..buildingItem.Type);
						if (buildingItem.Disabled) then
							if(showDisabled) then
								buildingListing.Disabled:SetHide(false);
								buildingListing.Button:SetColor(COLOR_LOW_OPACITY);
							else
								buildingListing.Button:SetHide(true);
							end
						else
							buildingListing.Button:SetHide(false);
							buildingListing.Disabled:SetHide(true);
							buildingListing.Button:SetSizeY(BUTTON_Y);
							buildingListing.Button:SetColor(0xffffffff);
						end
						buildingListing.Button:SetDisabled(buildingItem.Disabled);
						buildingListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
						buildingListing.Button:RegisterCallback( Mouse.eLClick, function()
							QueueBuilding(data.City, buildingItem);
						end);

						buildingListing.Button:RegisterCallback( Mouse.eMClick, function()
							QueueBuilding(data.City, buildingItem, true);
							RecenterCameraToSelectedCity();
						end);

						if(not IsTutorialRunning()) then
							buildingListing.Button:RegisterCallback( Mouse.eRClick, function()
								LuaEvents.OpenCivilopedia(buildingItem.Type);
							end);
						end

						buildingListing.Button:SetTag(UITutorialManager:GetHash(buildingItem.Type));

					end
				end
			end

			-- Populate Wonders ------------------------ CANNOT purchase wonders
			wonderList = listIM:GetInstance();
			wonderList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_WONDERS")));
			wonderList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_CITY_WONDERS")));
			local wL = wonderList;
			if ( wonderList.wonderListIM ~= nil ) then
				wonderList.wonderListIM:ResetInstances()
			else
				wonderList.wonderListIM = InstanceManager:new( "BuildingListInstance", "Root", wonderList.List);
			end

			for i, item in ipairs(data.BuildingItems) do
				if(item.IsWonder and not IsWonderInQueue(item.Hash)) then
					local wonderListing = wonderList["wonderListIM"]:GetInstance();
					ResetInstanceVisibility(wonderListing);
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							wonderListing.RecommendedIcon:SetHide(false);
						end
					end
					local nameStr = Locale.Lookup("{1_Name}", item.Name);
					if (item.Repair) then
						nameStr = nameStr .. "[NEWLINE]" .. Locale.Lookup("LOC_PRODUCTION_ITEM_REPAIR");
					end
					wonderListing.LabelText:SetText(nameStr);

					if(item.Progress > 0) then
						wonderListing.ProductionProgressArea:SetHide(false);
						local wonderProgress = item.Progress/item.Cost;
						if (wonderProgress < 1) then
							wonderListing.ProductionProgress:SetPercent(wonderProgress);
						else
							wonderListing.ProductionProgressArea:SetHide(true);
						end
					else
						wonderListing.ProductionProgressArea:SetHide(true);
					end
					local turnsStrTT:string = "";
					local turnsStr:string = "";
					local numberOfTurns = item.TurnsLeft;
					if numberOfTurns == -1 then
						numberOfTurns = "999+";
						turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
					else
						turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
					end
					turnsStr = numberOfTurns .. "[ICON_Turn]";
					wonderListing.CostText:SetText(turnsStr);
					wonderListing.CostText:SetToolTipString(turnsStrTT);
					wonderListing.Button:SetToolTipString(item.ToolTip);
					wonderListing.Disabled:SetToolTipString(item.ToolTip);
					wonderListing.Icon:SetIcon(ICON_PREFIX..item.Type);
					if (item.Disabled) then
						if(showDisabled) then
							wonderListing.Disabled:SetHide(false);
							wonderListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							wonderListing.Button:SetHide(true);
						end
					else
						wonderListing.Button:SetHide(false);
						wonderListing.Disabled:SetHide(true);
						wonderListing.Button:SetSizeY(BUTTON_Y);
						wonderListing.Button:SetColor(0xffffffff);
					end
					wonderListing.Button:SetDisabled(item.Disabled);
					wonderListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
					wonderListing.Button:RegisterCallback( Mouse.eLClick, function()
						nextDistrictSkipToFront = false;
						QueueBuilding(data.City, item);
					end);

					wonderListing.Button:RegisterCallback( Mouse.eMClick, function()
						nextDistrictSkipToFront = true;
						QueueBuilding(data.City, item, true);
						RecenterCameraToSelectedCity();
					end);

					if(not IsTutorialRunning()) then
						wonderListing.Button:RegisterCallback( Mouse.eRClick, function()
							LuaEvents.OpenCivilopedia(item.Type);
						end);
					end

					wonderListing.Button:SetTag(UITutorialManager:GetHash(item.Type));
				end
			end

			wonderList.List:CalculateSize();
			wonderList.List:ReprocessAnchoring();

			if (wonderList.List:GetSizeY()==0) then
				wonderList.Top:SetHide(true);
			else
				m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
				wonderList.Header:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				wonderList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(wL);
					end);
				wonderList.HeaderOn:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				wonderList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(wL);
					end);
			end
			prodWonderList = wL;


			--===================================================================================================================
			------------------------------------------ Populate the Production Queue --------------------------------------------
			--===================================================================================================================
			m_queueIM:ResetInstances();
			if(#prodQueue[cityID] > 0) then
				queueList = m_queueIM:GetInstance();

				if (queueList.queueListIM ~= nil) then
					queueList.queueListIM:ResetInstances();
				else
					queueList.queueListIM = InstanceManager:new("QueueListInstance", "Root", queueList.List);
				end

				local itemEncountered = {};

				for i, qi in pairs(prodQueue[cityID]) do
					local queueListing = queueList["queueListIM"]:GetInstance();
					ResetInstanceVisibility(queueListing);
					queueListing.ProductionProgressArea:SetHide(true);

					if(qi.entry) then
						local info = GetProductionInfoOfCity(selectedCity, qi.entry.Hash);
						local turnsText = info.Turns;

						if(itemEncountered[qi.entry.Hash]) then
							turnsText = math.ceil(info.Cost / cityData.ProductionPerTurn);
						else
							if(info.Progress > 0) then
								queueListing.ProductionProgressArea:SetHide(false);

								local progress = info.Progress/info.Cost;
								if (progress < 1) then
									queueListing.ProductionProgress:SetPercent(progress);
								else
									queueListing.ProductionProgressArea:SetHide(true);
								end
							end
						end

						local suffix = "";

						if(GameInfo.Units[qi.entry.Hash]) then
							local unitDef = GameInfo.Units[qi.entry.Hash];
							local cost = 0;

							if(prodQueue[cityID][i].type == PRODUCTION_TYPE.CORPS) then
								cost = qi.entry.CorpsCost;
								if(unitDef.Domain == "DOMAIN_SEA") then
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
								else
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
								end
							elseif(qi.type == PRODUCTION_TYPE.ARMY) then
								cost = qi.entry.ArmyCost;
								if(unitDef.Domain == "DOMAIN_SEA") then
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
								else
									suffix = " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
								end
							elseif(qi.type == PRODUCTION_TYPE.UNIT) then
								cost = qi.entry.Cost;
							end

							if(itemEncountered[qi.entry.Hash] and info.Progress ~= 0) then
								turnsText = math.ceil(cost / cityData.ProductionPerTurn);
								local percentPerTurn = info.PercentCompleteNextTurn - info.PercentComplete;
								if(info.PercentCompleteNextTurn < 1) then
									turnsText = math.ceil(1/percentPerTurn);
								else
									turnsText = "~" .. turnsText;
								end
							else
								turnsText = info.Turns;
								local progress = info.Progress / cost;
								if (progress < 1) then
									queueListing.ProductionProgress:SetPercent(progress);
								end
							end
						end

						if(qi.entry.Repair) then suffix = " (" .. Locale.Lookup("LOC_UNITOPERATION_REPAIR_DESCRIPTION") .. ")" end

						queueListing.LabelText:SetText(Locale.Lookup(qi.entry.Name) .. suffix);
						queueListing.Icon:SetIcon(info.Icon)
						queueListing.CostText:SetText(turnsText .. "[ICON_Turn]");
						if(i == 1) then queueListing.Active:SetHide(false); end

						itemEncountered[qi.entry.Hash] = true;
					end

					-- EVENT HANDLERS --
					queueListing.Button:RegisterCallback( Mouse.eRClick, function()
						if(CanRemoveFromQueue(cityID, i)) then
							if(RemoveFromQueue(cityID, i)) then
								if(i == 1) then
									BuildFirstQueued(selectedCity);
								else
									Refresh(true);
								end
							end
						end
					end);

					queueListing.Button:RegisterCallback( Mouse.eMouseEnter, function()
						if(not UILens.IsLayerOn( LensLayers.DISTRICTS ) and qi.plotID > -1) then
							UILens.SetAdjacencyBonusDistict(qi.plotID, "Placement_Valid", {})
						end
					end);

					queueListing.Button:RegisterCallback( Mouse.eMouseExit, function()
						if(not UILens.IsLayerOn( LensLayers.DISTRICTS )) then
							UILens.ClearLayerHexes( LensLayers.DISTRICTS );
						end
					end);

					queueListing.Button:RegisterCallback( Mouse.eLDblClick, function()
						MoveQueueIndex(cityID, i, 1);
						BuildFirstQueued(selectedCity);
					end);

					queueListing.Button:RegisterCallback( Mouse.eMClick, function()
						MoveQueueIndex(cityID, i, 1);
						BuildFirstQueued(selectedCity);
						RecenterCameraToSelectedCity();
					end);

					queueListing.Draggable:RegisterCallback( Drag.eDown, function(dragStruct) OnDownInQueue(dragStruct, queueListing, i); end );
					queueListing.Draggable:RegisterCallback( Drag.eDrop, function(dragStruct) OnDropInQueue(dragStruct, queueListing, i); end );

					BuildProductionQueueDropArea( queueListing.Button,	i,	"QUEUE_"..i );
				end
			end
		end --End if LISTMODE.PRODUCTION - display districts, NESTED buildings, and wonders

		if(listMode ~= LISTMODE.PRODUCTION) then			--If we are purchasing, then buildings don't have to be displayed in a nested way

			-- Populate Districts ------------------------
			districtList = listIM:GetInstance();
			districtList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS")));
			districtList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_DISTRICTS")));
			local dL = districtList;
			if ( districtList.districtListIM ~= nil) then
				districtList.districtListIM:ResetInstances();
			else
				districtList.districtListIM = InstanceManager:new( "DistrictListInstance", "Root", districtList.List);
			end

			for i, item in ipairs(data.DistrictPurchases) do
				if (item.Yield == "YIELD_GOLD" and listMode == LISTMODE.PURCHASE_GOLD) then
					local districtListing = districtList["districtListIM"]:GetInstance();
					ResetInstanceVisibility(districtListing);
					districtListing.ProductionProgressArea:SetHide(true);
					local nameStr = Locale.Lookup(item.Name);
					local costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.Cost);
					if (item.CantAfford) then
						costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
					end
					for _,hash in ipairs( m_recommendedItems) do
						if (item.Hash == hash.BuildItemHash) then
							districtListing.RecommendedIcon:SetHide(false);
						end
					end
					districtListing.LabelText:SetText(nameStr);
					districtListing.CostText:SetText(costStr);
					districtListing.Button:SetToolTipString(item.ToolTip);
					districtListing.Disabled:SetToolTipString(item.ToolTip);
					districtListing.Icon:SetIcon(ICON_PREFIX..item.Type);
					if (item.Disabled) then
						if(showDisabled) then
							districtListing.Disabled:SetHide(false);
							districtListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							districtListing.Button:SetHide(true);
						end
					else
						districtListing.Button:SetHide(false);
						districtListing.Disabled:SetHide(true);
						districtListing.Button:SetColor(0xffffffff);
					end
					districtListing.Button:SetDisabled(item.Disabled);

					districtListing.Button:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

					districtListing.Button:RegisterCallback( Mouse.eLClick, function()
							PurchaseDistrict(data.City, item);
						end);

				end
			end

			-- Populate Buildings ------------------------
			buildingList = listIM:GetInstance();
			buildingList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_BUILDINGS")));
			buildingList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_BUILDINGS")));
			local bL = buildingList;
			if ( buildingList.buildingListIM ~= nil ) then
				buildingList.buildingListIM:ResetInstances();
			else
				buildingList.buildingListIM = InstanceManager:new( "BuildingListInstance", "Root", buildingList.List);
			end

			for i, item in ipairs(data.BuildingPurchases) do
				if ((item.Yield == "YIELD_GOLD" and listMode == LISTMODE.PURCHASE_GOLD) or (item.Yield == "YIELD_FAITH" and listMode == LISTMODE.PURCHASE_FAITH)) then
					local buildingListing = buildingList["buildingListIM"]:GetInstance();
					ResetInstanceVisibility(buildingListing);
					buildingListing.ProductionProgressArea:SetHide(true);						-- Since this is DEFINITELY a purchase instance, hide the progress bar
					local nameStr = Locale.Lookup(item.Name);
					local costStr;
					if (item.Yield == "YIELD_GOLD") then
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.Cost);
					else
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.Cost);
					end
					if item.CantAfford then
						costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
					end
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							buildingListing.RecommendedIcon:SetHide(false);
						end
					end
					buildingListing.LabelText:SetText(nameStr);
					buildingListing.CostText:SetText(costStr);
					buildingListing.Button:SetToolTipString(item.ToolTip);
					buildingListing.Disabled:SetToolTipString(item.ToolTip);
					buildingListing.Icon:SetIcon(ICON_PREFIX..item.Type);
					if (item.Disabled) then
						if(showDisabled) then
							buildingListing.Disabled:SetHide(false);
							buildingListing.Button:SetColor(COLOR_LOW_OPACITY);
						else
							buildingListing.Button:SetHide(true);
						end
					else
						buildingListing.Button:SetHide(false);
						buildingListing.Disabled:SetHide(true);
						buildingListing.Button:SetColor(0xffffffff);
					end
					buildingListing.Button:SetDisabled(item.Disabled);

					if(not IsTutorialRunning()) then
						buildingListing.Button:RegisterCallback( Mouse.eRClick, function()
							LuaEvents.OpenCivilopedia(item.Type);
						end);
					end

					buildingListing.Button:RegisterCallback( Mouse.eLClick, function()
							PurchaseBuilding(data.City, item);
						end);
				end
			end

			buildingList.List:CalculateSize();
			buildingList.List:ReprocessAnchoring();

			if (buildingList.List:GetSizeY()==0) then
				buildingList.Top:SetHide(true);
			else
				m_maxPurchaseSize = m_maxPurchaseSize + HEADER_Y + SEPARATOR_Y;
				buildingList.Header:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				buildingList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(bL);
					end);
				buildingList.HeaderOn:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				buildingList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(bL);
					end);
			end

			if( listMode== LISTMODE.PURCHASE_GOLD) then
				purchGoldBuildingList = bL;
			elseif (listMode == LISTMODE.PURCHASE_FAITH) then
				purchFaithBuildingList = bL;
			end
		end -- End if NOT LISTMODE.PRODUCTION

		-- Populate Units ------------------------
		local primaryColor, secondaryColor  = UI.GetPlayerColors( Players[Game.GetLocalPlayer()]:GetID() );
		local darkerFlagColor	:number = DarkenLightenColor(primaryColor,(-85),255);
		local brighterFlagColor :number = DarkenLightenColor(primaryColor,90,255);
		local brighterIconColor :number = DarkenLightenColor(secondaryColor,20,255);
		local darkerIconColor	:number = DarkenLightenColor(secondaryColor,-30,255);

		unitList = listIM:GetInstance();
		unitList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_TECH_FILTER_UNITS")));
		unitList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_TECH_FILTER_UNITS")));
		local uL = unitList;
		if ( unitList.unitListIM ~= nil ) then
			unitList.unitListIM:ResetInstances();
		else
			unitList.unitListIM = InstanceManager:new( "UnitListInstance", "Root", unitList.List);
		end
		if ( unitList.civilianListIM ~= nil ) then
			unitList.civilianListIM:ResetInstances();
		else
			unitList.civilianListIM = InstanceManager:new( "CivilianListInstance",	"Root", unitList.List);
		end

		local unitData;
		if(listMode == LISTMODE.PRODUCTION) then
			unitData = data.UnitItems;
		else
			unitData = data.UnitPurchases;
		end
		for i, item in ipairs(unitData) do
			local unitListing;
			if ((item.Yield == "YIELD_GOLD" and listMode == LISTMODE.PURCHASE_GOLD) or (item.Yield == "YIELD_FAITH" and listMode == LISTMODE.PURCHASE_FAITH) or listMode == LISTMODE.PRODUCTION) then

				if (item.Civilian) then
					unitListing = unitList["civilianListIM"]:GetInstance();
				else
					unitListing = unitList["unitListIM"]:GetInstance();
				end
				ResetInstanceVisibility(unitListing);
				-- Check to see if this item is recommended
				for _,hash in ipairs( m_recommendedItems) do
					if(item.Hash == hash.BuildItemHash) then
						unitListing.RecommendedIcon:SetHide(false);
					end
				end

				local costStr = "";
				local costStrTT = "";
				if(listMode == LISTMODE.PRODUCTION) then
					-- ProductionQueue: We need to check that there isn't already one of these in the queue
					if(prodQueue[cityID][1] and prodQueue[cityID][1].entry.Hash == item.Hash) then
						item.TurnsLeft = math.ceil(item.Cost / cityData.ProductionPerTurn);
						item.Progress = 0;
					end

					-- Production meter progress for parent unit
					if(item.Progress > 0) then
						unitListing.ProductionProgressArea:SetHide(false);
						local unitProgress = item.Progress/item.Cost;
						if (unitProgress < 1) then
							unitListing.ProductionProgress:SetPercent(unitProgress);
						else
							unitListing.ProductionProgressArea:SetHide(true);
						end
					else
						unitListing.ProductionProgressArea:SetHide(true);
					end
					local numberOfTurns = item.TurnsLeft;
					if numberOfTurns == -1 then
						numberOfTurns = "999+";
						costStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
					else
						costStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.TurnsLeft);
					end
					costStr = numberOfTurns .. "[ICON_Turn]";
				else
					unitListing.ProductionProgressArea:SetHide(true);
					if (item.Yield == "YIELD_GOLD") then
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.Cost);
					else
						costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.Cost);
					end
					if item.CantAfford then
						costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
					end
				end

				-- PQ: Check if we already have max spies including queued
				if(item.Hash == GameInfo.Units["UNIT_SPY"].Hash) then
					local localDiplomacy = localPlayer:GetDiplomacy();
					local spyCap = localDiplomacy:GetSpyCapacity();
					local numberOfSpies = 0;

					-- Count our spies
					local localPlayerUnits:table = localPlayer:GetUnits();
					for i, unit in localPlayerUnits:Members() do
						local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
						if unitInfo.Spy then
							numberOfSpies = numberOfSpies + 1;
						end
					end

					-- Loop through all players to see if they have any of our captured spies
					local players:table = Game.GetPlayers();
					for i, player in ipairs(players) do
						local playerDiplomacy:table = player:GetDiplomacy();
						local numCapturedSpies:number = playerDiplomacy:GetNumSpiesCaptured();
						for i=0,numCapturedSpies-1,1 do
							local spyInfo:table = playerDiplomacy:GetNthCapturedSpy(player:GetID(), i);
							if spyInfo and spyInfo.OwningPlayer == Game.GetLocalPlayer() then
								numberOfSpies = numberOfSpies + 1;
							end
						end
					end

					-- Count travelling spies
					if localDiplomacy then
						local numSpiesOffMap:number = localDiplomacy:GetNumSpiesOffMap();
						for i=0,numSpiesOffMap-1,1 do
							local spyOffMapInfo:table = localDiplomacy:GetNthOffMapSpy(Game.GetLocalPlayer(), i);
							if spyOffMapInfo and spyOffMapInfo.ReturnTurn ~= -1 then
								numberOfSpies = numberOfSpies + 1;
							end
						end
					end

	  				if(spyCap > numberOfSpies) then
	  					for _,city in pairs(prodQueue) do
							for _,qi in pairs(city) do
								if(qi.entry.Hash == item.Hash) then
									numberOfSpies = numberOfSpies + 1;
								end
							end
						end
						if(numberOfSpies >= spyCap) then
							item.Disabled = true;
							-- No existing localization string for "Need more spy slots" so we'll just gray it out
							-- item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("???");
						end
	  				end
				end

				-- PQ: Check if we already have max traders queued
				if(item.Hash == GameInfo.Units["UNIT_TRADER"].Hash) then
					local playerTrade	:table	= localPlayer:GetTrade();
					local routesActive	:number = playerTrade:GetNumOutgoingRoutes();
					local routesCapacity:number = playerTrade:GetOutgoingRouteCapacity();
					local routesQueued  :number = 0;

					if(routesCapacity >= routesActive) then
						for _,city in pairs(prodQueue) do
							for _,qi in pairs(city) do
								if(qi.entry.Hash == item.Hash) then
									routesQueued = routesQueued + 1;
								end
							end
						end
						if(routesActive + routesQueued >= routesCapacity) then
							item.Disabled = true;
							if(not string.find(item.ToolTip, "[COLOR:Red]")) then
								item.ToolTip = item.ToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup("LOC_UNIT_TRAIN_FULL_TRADE_ROUTE_CAPACITY");
							end
						end
					end
				end

				local nameStr = Locale.Lookup("{1_Name}", item.Name);
				unitListing.LabelText:SetText(nameStr);
				unitListing.CostText:SetText(costStr);
				if(costStrTT ~= "") then
					unitListing.CostText:SetToolTipString(costStrTT);
				end
				unitListing.TrainUnit:SetToolTipString(item.ToolTip);
				unitListing.Disabled:SetToolTipString(item.ToolTip);

				-- Show/hide religion indicator icon
				if unitListing.ReligionIcon then
					local showReligionIcon:boolean = false;

					if item.ReligiousStrength and item.ReligiousStrength > 0 then
						if unitListing.ReligionIcon then
							local religionType = data.City:GetReligion():GetMajorityReligion();
							if religionType > 0 then
								local religion:table = GameInfo.Religions[religionType];
								local religionIcon:string = "ICON_" .. religion.ReligionType;
								local religionColor:number = UI.GetColorValue(religion.Color);

								unitListing.ReligionIcon:SetIcon(religionIcon);
								unitListing.ReligionIcon:SetColor(religionColor);
								unitListing.ReligionIcon:LocalizeAndSetToolTip(religion.Name);
								unitListing.ReligionIcon:SetHide(false);
								showReligionIcon = true;
							end
						end
					end

					unitListing.ReligionIcon:SetHide(not showReligionIcon);
				end

				-- Set Icon color and backing
				local textureName = TEXTURE_BASE;
				if item.Type ~= -1 then
					if (GameInfo.Units[item.Type].Combat ~= 0 or GameInfo.Units[item.Type].RangedCombat ~= 0) then		-- Need a simpler what to test if the unit is a combat unit or not.
						if "DOMAIN_SEA" == GameInfo.Units[item.Type].Domain then
							textureName = TEXTURE_NAVAL;
						else
							textureName =  TEXTURE_BASE;
						end
					else
						if GameInfo.Units[item.Type].MakeTradeRoute then
							textureName = TEXTURE_TRADE;
						elseif "FORMATION_CLASS_SUPPORT" == GameInfo.Units[item.Type].FormationClass then
							textureName = TEXTURE_SUPPORT;
						elseif item.ReligiousStrength > 0 then
							textureName = TEXTURE_RELIGION;
						else
							textureName = TEXTURE_CIVILIAN;
						end
					end
				end

				-- Set colors and icons for the flag instance
				unitListing.FlagBase:SetTexture(textureName);
				unitListing.FlagBaseOutline:SetTexture(textureName);
				unitListing.FlagBaseDarken:SetTexture(textureName);
				unitListing.FlagBaseLighten:SetTexture(textureName);
				unitListing.FlagBase:SetColor( primaryColor );
				unitListing.FlagBaseOutline:SetColor( primaryColor );
				unitListing.FlagBaseDarken:SetColor( darkerFlagColor );
				unitListing.FlagBaseLighten:SetColor( brighterFlagColor );
				unitListing.Icon:SetColor( secondaryColor );
				unitListing.Icon:SetIcon(ICON_PREFIX..item.Type);

				-- Handle if the item is disabled
				if (item.Disabled) then
					if(showDisabled) then
						unitListing.Disabled:SetHide(false);
						unitListing.TrainUnit:SetColor(COLOR_LOW_OPACITY);
						unitListing.RecommendedIcon:SetHide(true);
					else
						unitListing.TrainUnit:SetHide(true);
					end
				else
					unitListing.TrainUnit:SetHide(false);
					unitListing.Disabled:SetHide(true);
					unitListing.TrainUnit:SetColor(0xffffffff);
				end
				unitListing.TrainUnit:SetDisabled(item.Disabled);
				unitListing.TrainUnit:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
				if (listMode == LISTMODE.PRODUCTION) then
					unitListing.TrainUnit:RegisterCallback( Mouse.eLClick, function()
						QueueUnit(data.City, item, m_isCONTROLpressed);
						end);

					unitListing.TrainUnit:RegisterCallback( Mouse.eMClick, function()
						QueueUnit(data.City, item, true);
						RecenterCameraToSelectedCity();
						end);
				else
					unitListing.TrainUnit:RegisterCallback( Mouse.eLClick, function()
						PurchaseUnit(data.City, item);
						end);
				end

				if(not IsTutorialRunning()) then
					unitListing.TrainUnit:RegisterCallback( Mouse.eRClick, function()
						LuaEvents.OpenCivilopedia(item.Type);
					end);
				end

				unitListing.TrainUnit:SetTag(UITutorialManager:GetHash(item.Type));

				-- Controls for training unit corps and armies.
				-- Want a special text string for this!! #NEW TEXT #LOCALIZATION - "You can only directly build corps and armies once you have constructed a military academy."
				-- LOC_UNIT_TRAIN_NEED_MILITARY_ACADEMY
				if item.Corps or item.Army then
					--if (item.Disabled) then
					--	if(showDisabled) then
					--		unitListing.CorpsDisabled:SetHide(false);
					--		unitListing.ArmyDisabled:SetHide(false);
					--	end
					--end
					unitListing.CorpsArmyDropdownArea:SetHide(false);
					unitListing.CorpsArmyDropdownButton:RegisterCallback( Mouse.eLClick, function()
							local isExpanded = unitListing.CorpsArmyArrow:IsSelected();
							unitListing.CorpsArmyArrow:SetSelected(not isExpanded);
							unitListing.ArmyCorpsDrawer:SetHide(not isExpanded);
							unitList.List:CalculateSize();
							unitList.List:ReprocessAnchoring();
							unitList.Top:CalculateSize();
							unitList.Top:ReprocessAnchoring();
							if(listMode == LISTMODE.PRODUCTION) then
								Controls.ProductionList:CalculateSize();
								Controls.ProductionListScroll:CalculateSize();
							elseif(listMode == LISTMODE.PURCHASE_GOLD) then
								Controls.PurchaseList:CalculateSize();
								Controls.PurchaseListScroll:CalculateSize();
							elseif(listMode == LISTMODE.PURCHASE_FAITH) then
								Controls.PurchaseFaithList:CalculateSize();
								Controls.PurchaseFaithListScroll:CalculateSize();
							end
							end);
				end

				if item.Corps then
					-- Check to see if this item is recommended
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							unitListing.CorpsRecommendedIcon:SetHide(false);
						end
					end
					unitListing.CorpsButtonContainer:SetHide(false);
					-- Production meter progress for corps unit
					if (listMode == LISTMODE.PRODUCTION) then
						-- ProductionQueue: We need to check that there isn't already one of these in the queue
						if(IsHashInQueue(selectedCity, item.Hash)) then
							item.CorpsTurnsLeft = math.ceil(item.CorpsCost / cityData.ProductionPerTurn);
							item.Progress = 0;
						end

						if(item.Progress > 0) then
							unitListing.ProductionCorpsProgressArea:SetHide(false);
							local unitProgress = item.Progress/item.CorpsCost;
							if (unitProgress < 1) then
								unitListing.ProductionCorpsProgress:SetPercent(unitProgress);
							else
								unitListing.ProductionCorpsProgressArea:SetHide(true);
							end
						else
							unitListing.ProductionCorpsProgressArea:SetHide(true);
						end
						local turnsStr = item.CorpsTurnsLeft .. "[ICON_Turn]";
						local turnsStrTT = item.CorpsTurnsLeft .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.CorpsTurnsLeft);
						unitListing.CorpsCostText:SetText(turnsStr);
						unitListing.CorpsCostText:SetToolTipString(turnsStrTT);
					else
						unitListing.ProductionCorpsProgressArea:SetHide(true);
						if (item.Yield == "YIELD_GOLD") then
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.CorpsCost);
						else
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.CorpsCost);
						end
						if (item.CorpsDisabled) then
							if (showDisabled) then
								unitListing.CorpsDisabled:SetHide(false);
							end
							costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
						end
						unitListing.CorpsCostText:SetText(costStr);
					end


					unitListing.CorpsLabelIcon:SetText(item.CorpsName);
					unitListing.CorpsLabelText:SetText(nameStr);

					unitListing.CorpsFlagBase:SetTexture(textureName);
					unitListing.CorpsFlagBaseOutline:SetTexture(textureName);
					unitListing.CorpsFlagBaseDarken:SetTexture(textureName);
					unitListing.CorpsFlagBaseLighten:SetTexture(textureName);
					unitListing.CorpsFlagBase:SetColor( primaryColor );
					unitListing.CorpsFlagBaseOutline:SetColor( primaryColor );
					unitListing.CorpsFlagBaseDarken:SetColor( darkerFlagColor );
					unitListing.CorpsFlagBaseLighten:SetColor( brighterFlagColor );
					unitListing.CorpsIcon:SetColor( secondaryColor );
					unitListing.CorpsIcon:SetIcon(ICON_PREFIX..item.Type);
					unitListing.TrainCorpsButton:SetToolTipString(item.CorpsTooltip);
					unitListing.CorpsDisabled:SetToolTipString(item.CorpsTooltip);
					if (listMode == LISTMODE.PRODUCTION) then
						unitListing.TrainCorpsButton:RegisterCallback( Mouse.eLClick, function()
							QueueUnitCorps(data.City, item);
						end);

						unitListing.TrainCorpsButton:RegisterCallback( Mouse.eMClick, function()
							QueueUnitCorps(data.City, item, true);
							RecenterCameraToSelectedCity();
						end);
					else
						unitListing.TrainCorpsButton:RegisterCallback( Mouse.eLClick, function()
							PurchaseUnitCorps(data.City, item);
						end);
					end
				end
				if item.Army then
					-- Check to see if this item is recommended
					for _,hash in ipairs( m_recommendedItems) do
						if(item.Hash == hash.BuildItemHash) then
							unitListing.ArmyRecommendedIcon:SetHide(false);
						end
					end
					unitListing.ArmyButtonContainer:SetHide(false);

					if (listMode == LISTMODE.PRODUCTION) then
						-- ProductionQueue: We need to check that there isn't already one of these in the queue
						if(IsHashInQueue(selectedCity, item.Hash)) then
							item.ArmyTurnsLeft = math.ceil(item.ArmyCost / cityData.ProductionPerTurn);
							item.Progress = 0;
						end

						if(item.Progress > 0) then
							unitListing.ProductionArmyProgressArea:SetHide(false);
							local unitProgress = item.Progress/item.ArmyCost;
							unitListing.ProductionArmyProgress:SetPercent(unitProgress);
							if (unitProgress < 1) then
								unitListing.ProductionArmyProgress:SetPercent(unitProgress);
							else
								unitListing.ProductionArmyProgressArea:SetHide(true);
							end
						else
							unitListing.ProductionArmyProgressArea:SetHide(true);
						end
						local turnsStrTT:string = "";
						local turnsStr:string = "";
						local numberOfTurns = item.ArmyTurnsLeft;
						if numberOfTurns == -1 then
							numberOfTurns = "999+";
							turnsStrTT = Locale.Lookup("LOC_HUD_CITY_WILL_NOT_COMPLETE");
						else
							turnsStrTT = numberOfTurns .. Locale.Lookup("LOC_HUD_CITY_TURNS_TO_COMPLETE", item.ArmyTurnsLeft);
						end
						turnsStr = numberOfTurns .. "[ICON_Turn]";
						unitListing.ArmyCostText:SetText(turnsStr);
						unitListing.ArmyCostText:SetToolTipString(turnsStrTT);
					else
						unitListing.ProductionArmyProgressArea:SetHide(true);
						if (item.Yield == "YIELD_GOLD") then
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_GOLD_TEXT", item.ArmyCost);
						else
							costStr = Locale.Lookup("LOC_PRODUCTION_PURCHASE_FAITH_TEXT", item.ArmyCost);
						end
						if (item.ArmyDisabled) then
							if (showDisabled) then
								unitListing.ArmyDisabled:SetHide(false);
							end
							costStr = "[COLOR:Red]" .. costStr .. "[ENDCOLOR]";
						end
						unitListing.ArmyCostText:SetText(costStr);
					end

					unitListing.ArmyLabelIcon:SetText(item.ArmyName);
					unitListing.ArmyLabelText:SetText(nameStr);
					unitListing.ArmyFlagBase:SetTexture(textureName);
					unitListing.ArmyFlagBaseOutline:SetTexture(textureName);
					unitListing.ArmyFlagBaseDarken:SetTexture(textureName);
					unitListing.ArmyFlagBaseLighten:SetTexture(textureName);
					unitListing.ArmyFlagBase:SetColor( primaryColor );
					unitListing.ArmyFlagBaseOutline:SetColor( primaryColor );
					unitListing.ArmyFlagBaseDarken:SetColor( darkerFlagColor );
					unitListing.ArmyFlagBaseLighten:SetColor( brighterFlagColor );
					unitListing.ArmyIcon:SetColor( secondaryColor );
					unitListing.ArmyIcon:SetIcon(ICON_PREFIX..item.Type);
					unitListing.TrainArmyButton:SetToolTipString(item.ArmyTooltip);
					unitListing.ArmyDisabled:SetToolTipString(item.ArmyTooltip);
					if (listMode == LISTMODE.PRODUCTION) then
						unitListing.TrainArmyButton:RegisterCallback( Mouse.eLClick, function()
							QueueUnitArmy(data.City, item);
						end);

						unitListing.TrainArmyButton:RegisterCallback( Mouse.eMClick, function()
							QueueUnitArmy(data.City, item, true);
							RecenterCameraToSelectedCity();
						end);
					else
						unitListing.TrainArmyButton:RegisterCallback( Mouse.eLClick, function()
							PurchaseUnitArmy(data.City, item);
						end);
					end
				end
			end -- end faith/gold check
		end -- end iteration through units

		unitList.List:CalculateSize();
		unitList.List:ReprocessAnchoring();

		if (unitList.List:GetSizeY()==0) then
			unitList.Top:SetHide(true);
		else
			m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
			unitList.Header:RegisterCallback( Mouse.eLClick, function()
				OnExpand(uL);
				end);
			unitList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
				OnCollapse(uL);
				end);
		end

		if( listMode== LISTMODE.PURCHASE_GOLD) then
			purchGoldUnitList = uL;
		elseif (listMode == LISTMODE.PURCHASE_FAITH) then
			purchFaithUnitList = uL;
		else
			prodUnitList = uL;
		end

		if(listMode == LISTMODE.PRODUCTION) then			--Projects can only be produced, not purchased
			-- Populate Projects ------------------------
			projectList = listIM:GetInstance();
			projectList.Header:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_PROJECTS")));
			projectList.HeaderOn:SetText(Locale.ToUpper(Locale.Lookup("LOC_HUD_PROJECTS")));
			local pL = projectList;
			if ( projectList.projectListIM ~= nil ) then
				projectList.projectListIM:ResetInstances();
			else
				projectList.projectListIM = InstanceManager:new( "ProjectListInstance", "Root", projectList.List);
			end

			-- Check for queued project and list it as well
			-- if(prodQueue[cityID] and prodQueue[cityID][1] and GameInfo.Projects[prodQueue[cityID][1].entry.Hash]) then
			-- 	local activeQueueItem = prodQueue[cityID][1].entry;
			-- 	table.insert(data.ProjectItems, activeQueueItem);
			-- end

			for i, item in ipairs(data.ProjectItems) do
				local projectListing = projectList.projectListIM:GetInstance();
				ResetInstanceVisibility(projectListing);
				-- Check to see if this item is recommended
				for _,hash in ipairs( m_recommendedItems) do
					if(item.Hash == hash.BuildItemHash) then
						projectListing.RecommendedIcon:SetHide(false);
					end
				end

				-- ProductionQueue: We need to check that there isn't already one of these in the queue
				if(IsHashInQueue(selectedCity, item.Hash)) then
					item.TurnsLeft = math.ceil(item.Cost / cityData.ProductionPerTurn);
					item.Progress = 0;
				end

				-- Production meter progress for project
				if(item.Progress > 0) then
					projectListing.ProductionProgressArea:SetHide(false);
					local projectProgress = item.Progress/item.Cost;
					if (projectProgress < 1) then
						projectListing.ProductionProgress:SetPercent(projectProgress);
					else
						projectListing.ProductionProgressArea:SetHide(true);
					end
				else
					projectListing.ProductionProgressArea:SetHide(true);
				end

				local numberOfTurns = item.TurnsLeft;
				if numberOfTurns == -1 then
					numberOfTurns = "999+";
				end;

				local nameStr = Locale.Lookup("{1_Name}", item.Name);
				local turnsStr = numberOfTurns .. "[ICON_Turn]";
				projectListing.LabelText:SetText(nameStr);
				projectListing.CostText:SetText(turnsStr);
				projectListing.Button:SetToolTipString(item.ToolTip);
				projectListing.Disabled:SetToolTipString(item.ToolTip);
				projectListing.Icon:SetIcon(ICON_PREFIX..item.Type);
				if (item.Disabled) then
					if(showDisabled) then
						projectListing.Disabled:SetHide(false);
						projectListing.Button:SetColor(COLOR_LOW_OPACITY);
					else
						projectListing.Button:SetHide(true);
					end
				else
					projectListing.Button:SetHide(false);
					projectListing.Disabled:SetHide(true);
					projectListing.Button:SetColor(0xffffffff);
				end
				projectListing.Button:SetDisabled(item.Disabled);
				projectListing.Button:RegisterCallback( Mouse.eLClick, function()
					QueueProject(data.City, item);
				end);

				projectListing.Button:RegisterCallback( Mouse.eMClick, function()
					QueueProject(data.City, item, true);
					RecenterCameraToSelectedCity();
				end);

				if(not IsTutorialRunning()) then
					projectListing.Button:RegisterCallback( Mouse.eRClick, function()
						LuaEvents.OpenCivilopedia(item.Type);
					end);
				end

				projectListing.Button:SetTag(UITutorialManager:GetHash(item.Type));
			end


			projectList.List:CalculateSize();
			projectList.List:ReprocessAnchoring();

			if (projectList.List:GetSizeY()==0) then
				projectList.Top:SetHide(true);
			else
				m_maxProductionSize = m_maxProductionSize + HEADER_Y + SEPARATOR_Y;
				projectList.Header:RegisterCallback( Mouse.eLClick, function()
					OnExpand(pL);
					end);
				projectList.HeaderOn:RegisterCallback( Mouse.eLClick, function()
					OnCollapse(pL);
					end);
			end

			prodProjectList = pL;
		end -- end if LISTMODE.PRODUCTION

		-----------------------------------
		if( listMode == LISTMODE.PRODUCTION) then
			m_maxProductionSize = m_maxProductionSize + districtList.List:GetSizeY() + unitList.List:GetSizeY() + projectList.List:GetSizeY();
		end
		Controls.ProductionList:CalculateSize();
		Controls.ProductionListScroll:CalculateSize();
		Controls.PurchaseList:CalculateSize();
		Controls.PurchaseListScroll:CalculateSize();
		Controls.PurchaseFaithList:CalculateSize();
		Controls.PurchaseFaithListScroll:CalculateSize();

		-- DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		--for _,data in ipairs( m_recommendedItems) do
		--	if(GameInfo.Types[data.BuildItemHash].Type ~= nil) then
		--		print("Hash = ".. GameInfo.Types[data.BuildItemHash].Type);
		--	else
		--		print("Invalid hash received = " .. data.BuildItemHash);
		--	end
		--end
		-- DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	end

	function OnLocalPlayerChanged()
		Refresh();
	end

	function OnPlayerTurnActivated(player, isFirstTimeThisTurn)
		if (isFirstTimeThisTurn and Game.GetLocalPlayer() == player) then
			CheckAndReplaceAllQueuesForUpgrades();
			Refresh();
			lastProductionCompletePerCity = {};
		end
	end

	-- Returns ( allReasons:string )
	function ComposeFailureReasonStrings( isDisabled:boolean, results:table )
		if isDisabled and results ~= nil then
			-- Are there any failure reasons?
			local pFailureReasons : table = results[CityCommandResults.FAILURE_REASONS];
			if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
				-- Collect them all!
				local allReasons : string = "";
				for i,v in ipairs(pFailureReasons) do
					allReasons = allReasons .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(v) .. "[ENDCOLOR]";
				end
				return allReasons;
			end
		end
		return "";
	end
	function ComposeProductionCostString( iProductionProgress:number, iProductionCost:number)
		-- Show production progress only if there is progress present
		if iProductionCost ~= 0 then
			local TXT_COST			:string = Locale.Lookup( "LOC_HUD_PRODUCTION_COST" );
			local TXT_PRODUCTION	:string = Locale.Lookup( "LOC_HUD_PRODUCTION" );
			local costString		:string = tostring(iProductionCost);

			if iProductionProgress > 0 then -- Only show fraction if build progress has been made.
				costString = tostring(iProductionProgress) .. "/" .. costString;
			end
			return "[NEWLINE][NEWLINE]" .. TXT_COST .. ": " .. costString .. " [ICON_Production] " .. TXT_PRODUCTION;
		end
		return "";
	end
	-- Returns ( tooltip:string, subtitle:string )
	function ComposeUnitCorpsStrings( sUnitName:string, sUnitDomain:string, iProdProgress:number, iCorpsCost:number )
		local tooltip	:string = Locale.Lookup( sUnitName ) .. " ";
		local subtitle	:string = "";
		if sUnitDomain == "DOMAIN_SEA" then
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
			subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_FLEET_SUFFIX") .. ")";
		else
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
			subtitle = "(" .. Locale.Lookup("LOC_HUD_UNIT_PANEL_CORPS_SUFFIX") .. ")";
		end
		tooltip = tooltip .. "[NEWLINE]---" .. ComposeProductionCostString( iProdProgress, iCorpsCost );
		return tooltip, subtitle;
	end
	function ComposeUnitArmyStrings( sUnitName:string, sUnitDomain:string, iProdProgress:number, iArmyCost:number )
		local tooltip	:string = Locale.Lookup( sUnitName ) .. " ";
		local subtitle	:string = "";
		if sUnitDomain == "DOMAIN_SEA" then
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
			subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMADA_SUFFIX")..")";
		else
			tooltip = tooltip .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
			subtitle = "("..Locale.Lookup("LOC_HUD_UNIT_PANEL_ARMY_SUFFIX")..")";
		end
		tooltip = tooltip .. "[NEWLINE]---" .. ComposeProductionCostString( iProdProgress, iArmyCost );
		return tooltip, subtitle;
	end

	-- Returns ( isPurchaseable:boolean, kEntry:table )
	function ComposeUnitForPurchase( row:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
		local YIELD_TYPE 	:number = GameInfo.Yields[sYield].Index;

		-- Should we display this option to the player?
		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_UNIT_TYPE] = row.Hash;
		tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
		if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
			local isCanStart, results			 = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
			local isDisabled			:boolean = not isCanStart;
			local allReasons			 :string = ComposeFailureReasonStrings( isDisabled, results );
			local sToolTip 				 :string = ToolTipHelper.GetUnitToolTip( row.Hash ) .. allReasons;
			local isCantAfford			:boolean = false;
			--print ( "UnitBuy ", row.UnitType,isCanStart );

			-- Collect some constants so we don't need to keep calling out to get them.
			local nCityID				:number = pCity:GetID();
			local pCityGold				 :table = pCity:GetGold();
			local TXT_INSUFFIENT_YIELD	:string = "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup( sCantAffordKey ) .. "[ENDCOLOR]";

			-- Affordability check
			if not pYieldSource:CanAfford( nCityID, row.Hash ) then
				sToolTip = sToolTip .. TXT_INSUFFIENT_YIELD;
				isDisabled = true;
				isCantAfford = true;
			end

			local pBuildQueue			:table  = pCity:GetBuildQueue();
			local nProductionCost		:number = pBuildQueue:GetUnitCost( row.Index );
			local nProductionProgress	:number = pBuildQueue:GetUnitProgress( row.Index );
			sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

			local kUnit	 :table = {
				Type				= row.UnitType;
				Name				= row.Name;
				ToolTip				= sToolTip;
				Hash				= row.Hash;
				Kind				= row.Kind;
				Civilian			= row.FormationClass == "FORMATION_CLASS_CIVILIAN";
				Disabled			= isDisabled;
				CantAfford			= isCantAfford,
				Yield				= sYield;
				Cost				= pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.STANDARD_MILITARY_FORMATION );
				ReligiousStrength	= row.ReligiousStrength;

				CorpsTurnsLeft	= 0;
				ArmyTurnsLeft	= 0;
				Progress		= 0;
			};

			-- Should we present options for building Corps or Army versions?
			if results ~= nil then
				kUnit.Corps = results[CityOperationResults.CAN_TRAIN_CORPS];
				kUnit.Army = results[CityOperationResults.CAN_TRAIN_ARMY];

				local nProdProgress	:number = pBuildQueue:GetUnitProgress( row.Index );
				if kUnit.Corps then
					local nCost = pBuildQueue:GetUnitCorpsCost( row.Index );
					kUnit.CorpsCost	= pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
					kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row.Name, row.Domain, nProdProgress, nCost );
					kUnit.CorpsDisabled = not pYieldSource:CanAfford( nCityID, row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
					if kUnit.CorpsDisabled then
						kUnit.CorpsTooltip = kUnit.CorpsTooltip .. TXT_INSUFFIENT_YIELD;
					end
				end

				if kUnit.Army then
					local nCost = pBuildQueue:GetUnitArmyCost( row.Index );
					kUnit.ArmyCost	= pCityGold:GetPurchaseCost( YIELD_TYPE, row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
					kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row.Name, row.Domain, nProdProgress, nCost );
					kUnit.ArmyDisabled = not pYieldSource:CanAfford( nCityID, row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
					if kUnit.ArmyDisabled then
						kUnit.ArmyTooltip = kUnit.ArmyTooltip .. TXT_INSUFFIENT_YIELD;
					end
				end
			end

			return true, kUnit;
		end
		return false, nil;
	end
	function ComposeBldgForPurchase( pRow:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
		local YIELD_TYPE 	:number = GameInfo.Yields[sYield].Index;

		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_BUILDING_TYPE] = pRow.Hash;
		tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
		if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
			local isCanStart, pResults		 = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
			local isDisabled		:boolean = not isCanStart;
			local sAllReasons		 :string = ComposeFailureReasonStrings( isDisabled, pResults );
			local sToolTip 			 :string = ToolTipHelper.GetBuildingToolTip( pRow.Hash, playerID, pCity ) .. sAllReasons;
			local isCantAfford		:boolean = false;

			-- Affordability check
			if not pYieldSource:CanAfford( cityID, pRow.Hash ) then
				sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(sCantAffordKey) .. "[ENDCOLOR]";
				isDisabled = true;
				isCantAfford = true;
			end

			local pBuildQueue			:table  = pCity:GetBuildQueue();
			local iProductionCost		:number = pBuildQueue:GetBuildingCost( pRow.Index );
			local iProductionProgress	:number = pBuildQueue:GetBuildingProgress( pRow.Index );
			sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

			local kBuilding :table = {
				Type			= pRow.BuildingType,
				Name			= pRow.Name,
				ToolTip			= sToolTip,
				Hash			= pRow.Hash,
				Kind			= pRow.Kind,
				Disabled		= isDisabled,
				CantAfford		= isCantAfford,
				Cost			= pCity:GetGold():GetPurchaseCost( YIELD_TYPE, pRow.Hash ),
				Yield			= sYield
			};
			return true, kBuilding;
		end
		return false, nil;
	end

	function ComposeDistrictForPurchase( pRow:table, pCity:table, sYield:string, pYieldSource:table, sCantAffordKey:string )
		local YIELD_TYPE 	:number = GameInfo.Yields[sYield].Index;

		local tParameters = {};
		tParameters[CityCommandTypes.PARAM_DISTRICT_TYPE] = pRow.Hash;
		tParameters[CityCommandTypes.PARAM_YIELD_TYPE] = YIELD_TYPE;
		if CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, true, tParameters, false ) then
			local isCanStart, pResults		 = CityManager.CanStartCommand( pCity, CityCommandTypes.PURCHASE, false, tParameters, true );
			local isDisabled		:boolean = not isCanStart;
			local sAllReasons		:string = ComposeFailureReasonStrings( isDisabled, pResults );
			local sToolTip 			:string = ToolTipHelper.GetDistrictToolTip( pRow.Hash ) .. sAllReasons;
			local isCantAfford		:boolean = false;

			-- Affordability check
			if not pYieldSource:CanAfford( cityID, pRow.Hash ) then
				sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. Locale.Lookup(sCantAffordKey) .. "[ENDCOLOR]";
				isDisabled = true;
				isCantAfford = true;
			end

			local pBuildQueue			:table  = pCity:GetBuildQueue();
			local iProductionCost		:number = pBuildQueue:GetDistrictCost( pRow.Index );
			local iProductionProgress	:number = pBuildQueue:GetDistrictProgress( pRow.Index );
			sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

			local kDistrict :table = {
				Type			= pRow.DistrictType,
				Name			= pRow.Name,
				ToolTip			= sToolTip,
				Hash			= pRow.Hash,
				Kind			= pRow.Kind,
				Disabled		= isDisabled,
				CantAfford		= isCantAfford,
				Cost			= pCity:GetGold():GetPurchaseCost( YIELD_TYPE, pRow.Hash ),
				Yield			= sYield
			};
			return true, kDistrict;
		end
		return false, nil;
	end
	-- ===========================================================================
	function Refresh(persistCollapse)
		local playerID	:number = Game.GetLocalPlayer();
		local pPlayer	:table = Players[playerID];
		if (pPlayer == nil) then
			return;
		end

		local selectedCity	= UI.GetHeadSelectedCity();

		if (selectedCity ~= nil) then
			local cityGrowth	= selectedCity:GetGrowth();
			local cityCulture	= selectedCity:GetCulture();
			local buildQueue	= selectedCity:GetBuildQueue();
			local playerTreasury= pPlayer:GetTreasury();
			local playerReligion= pPlayer:GetReligion();
			local cityGold		= selectedCity:GetGold();
			local cityBuildings = selectedCity:GetBuildings();
			local cityDistricts = selectedCity:GetDistricts();
			local cityID		= selectedCity:GetID();
			local cityData 		= GetCityData(selectedCity);
			local cityPlot 		= Map.GetPlot(selectedCity:GetX(), selectedCity:GetY());

			if(not prodQueue[cityID]) then prodQueue[cityID] = {}; end
			CheckAndReplaceQueueForUpgrades(selectedCity);

			local new_data = {
				City				= selectedCity,
				Population			= selectedCity:GetPopulation(),
				Owner				= selectedCity:GetOwner(),
				Damage				= pPlayer:GetDistricts():FindID( selectedCity:GetDistrictID() ):GetDamage(),
				TurnsUntilGrowth	= cityGrowth:GetTurnsUntilGrowth(),
				CurrentTurnsLeft	= buildQueue:GetTurnsLeft(),
				FoodSurplus			= cityGrowth:GetFoodSurplus(),
				CulturePerTurn		= cityCulture:GetCultureYield(),
				TurnsUntilExpansion = cityCulture:GetTurnsUntilExpansion(),
				DistrictItems		= {},
				BuildingItems		= {},
				UnitItems			= {},
				ProjectItems		= {},
				BuildingPurchases	= {},
				UnitPurchases		= {},
				DistrictPurchases	= {},
			};

			local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();

			for row in GameInfo.Districts() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end

				local isInPanelList 		:boolean = not row.InternalOnly;
				local bHasProducedDistrict	:boolean = cityDistricts:HasDistrict( row.Index );
				local isInQueue 			:boolean = IsHashInQueue( selectedCity, row.Hash );
				local turnsLeft 			:number	 = buildQueue:GetTurnsLeft( row.DistrictType );
				if (isInPanelList or isInQueue) and ( buildQueue:CanProduce( row.Hash, true ) or bHasProducedDistrict or isInQueue ) then
					local isCanProduceExclusion, results = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled			:boolean = not isCanProduceExclusion;

					if(isInQueue) then
						bHasProducedDistrict = true;
						turnsLeft = nil;
						isDisabled = true;
					end

					-- If at least one valid plot is found where the district can be built, consider it buildable.
					local plots :table = GetCityRelatedPlotIndexesDistrictsAlternative( selectedCity, row.Hash );
					if plots == nil or table.count(plots) == 0 then
						-- No plots available for district. Has player had already started building it?
						local isPlotAllocated :boolean = false;
						local pDistricts 		:table = selectedCity:GetDistricts();
						for _, pCityDistrict in pDistricts:Members() do
							if row.Index == pCityDistrict:GetType() then
								isPlotAllocated = true;
								break;
							end
						end
						-- If not, this district can't be built. Guarantee that isDisabled is set.
						if not isPlotAllocated then
							isDisabled = true;
						end
					end

					local allReasons			:string = ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip				:string = ToolTipHelper.GetToolTip(row.DistrictType, Game.GetLocalPlayer()) .. allReasons;

					local iProductionCost		:number = buildQueue:GetDistrictCost( row.Index );
					local iProductionProgress	:number = buildQueue:GetDistrictProgress( row.Index );
					sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

					table.insert( new_data.DistrictItems, {
						Type			= row.DistrictType,
						Name			= row.Name,
						ToolTip			= sToolTip,
						Hash			= row.Hash,
						Kind			= row.Kind,
						TurnsLeft		= turnsLeft,
						Disabled		= isDisabled,
						Repair			= cityDistricts:IsPillaged( row.Index ),
						Contaminated	= cityDistricts:IsContaminated( row.Index ),
						Cost			= iProductionCost,
						Progress		= iProductionProgress,
						HasBeenBuilt	= bHasProducedDistrict
					});
				end

				-- Can it be purchased with gold?
				local isAllowed, kDistrict = ComposeDistrictForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
				if isAllowed then
					table.insert( new_data.DistrictPurchases, kDistrict );
				end

			end

			for row in GameInfo.Buildings() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end

				-- PQ: Determine if we have requirements in the queue
				local hasPrereqTech = row.PrereqTech == nil;
				local hasPrereqCivic = row.PrereqCivic == nil;
				local isPrereqDistrictInQueue = false;
				local disabledTooltip = nil;
				local doShow = true;

				if(not row.IsWonder) then
					local prereqTech = GameInfo.Technologies[row.PrereqTech];
					local prereqCivic = GameInfo.Civics[row.PrereqCivic];
					local prereqDistrict = GameInfo.Districts[row.PrereqDistrict];

					if(prereqTech and pPlayer:GetTechs():HasTech(prereqTech.Index)) then hasPrereqTech = true; end
					if(prereqCivic and pPlayer:GetCulture():HasCivic(prereqCivic.Index)) then hasPrereqCivic = true; end
					if((prereqDistrict and IsHashInQueue( selectedCity, prereqDistrict.Hash)) or cityDistricts:HasDistrict(prereqDistrict.Index, true)) then
						isPrereqDistrictInQueue = true;

						if(not IsHashInQueue( selectedCity, prereqDistrict.Hash )) then
							if(cityDistricts:IsPillaged(prereqDistrict.Index)) then
								disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_PILLAGED");
							elseif(cityDistricts:IsContaminated(prereqDistrict.Index)) then
								disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_CONTAMINATED");
							end
						end
					end

					if(not isPrereqDistrictInQueue) then
						for replacesRow in GameInfo.DistrictReplaces() do
							if(row.PrereqDistrict == replacesRow.ReplacesDistrictType) then
								local replacementDistrict = GameInfo.Districts[replacesRow.CivUniqueDistrictType];
								if((replacementDistrict and IsHashInQueue( selectedCity, replacementDistrict.Hash)) or cityDistricts:HasDistrict(replacementDistrict.Index, true)) then
									isPrereqDistrictInQueue = true;

									if(not IsHashInQueue( selectedCity, replacementDistrict.Hash )) then
										if(cityDistricts:IsPillaged(replacementDistrict.Index)) then
											disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_PILLAGED");
										elseif(cityDistricts:IsContaminated(replacementDistrict.Index)) then
											disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_DISTRICT_IS_CONTAMINATED");
										end
									end
								end
								break;
							end
						end
					end

					if(not isPrereqDistrictInQueue) then
						local canBuild, reasons = buildQueue:CanProduce(row.BuildingType, false, true);
						if(not canBuild and reasons) then
							local pFailureReasons = reasons[CityCommandResults.FAILURE_REASONS];
							if pFailureReasons ~= nil and table.count( pFailureReasons ) > 0 then
								for i,v in ipairs(pFailureReasons) do
									if("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED" == v) then
										disabledTooltip = Locale.Lookup("LOC_BUILDING_CONSTRUCT_IS_OCCUPIED");
									end
								end
							end
						end
					end

					local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
					-- Check for unique buildings
					for replaceRow in GameInfo.BuildingReplaces() do
						if(replaceRow.CivUniqueBuildingType == row.BuildingType) then
							local traitName = "TRAIT_CIVILIZATION_" .. row.BuildingType;
							local isCorrectCiv = false;

							for traitRow in GameInfo.CivilizationTraits() do
								if(traitRow.TraitType == traitName and traitRow.CivilizationType == civTypeName) then
									isCorrectCiv = true;
									break;
								end
							end

							if(not isCorrectCiv) then
								doShow = false;
							end
						end

						if(replaceRow.ReplacesBuildingType == row.BuildingType) then
							local traitName = "TRAIT_CIVILIZATION_" .. replaceRow.CivUniqueBuildingType;
							local isCorrectCiv = false;

							for traitRow in GameInfo.CivilizationTraits() do
								if(traitRow.TraitType == traitName and traitRow.CivilizationType == civTypeName) then
									isCorrectCiv = true;
									break;
								end
							end

							if(isCorrectCiv) then
								doShow = false;
							end
						end
					end

					-- Check for building prereqs
					if(buildingPrereqs[row.BuildingType]) then
						local prereqInQueue = false;

						for prereqRow in GameInfo.BuildingPrereqs() do
							if(prereqRow.Building == row.BuildingType) then
								for replaceRow in GameInfo.BuildingReplaces() do
									if(replaceRow.ReplacesBuildingType == prereqRow.PrereqBuilding and IsHashInQueue(selectedCity, GameInfo.Buildings[replaceRow.CivUniqueBuildingType].Hash)) then
										prereqInQueue = true;
										break;
									end
								end

								if(prereqInQueue or IsHashInQueue(selectedCity, GameInfo.Buildings[prereqRow.PrereqBuilding].Hash)) then
									prereqInQueue = true;

									-- Check for buildings enabled by dominant religious beliefs
									if(GameInfo.Buildings[row.Hash].EnabledByReligion) then
										doShow = false;

										if ((table.count(cityData.Religions) > 1) or (cityData.PantheonBelief > -1)) then
											local modifierIDs = {};

											if cityData.PantheonBelief > -1 then
												local beliefType = GameInfo.Beliefs[cityData.PantheonBelief].BeliefType;
												for belief in GameInfo.BeliefModifiers() do
													if belief.BeliefType == beliefType then
														table.insert(modifierIDs, belief.ModifierID);
														break;
													end
												end
											end
											if (table.count(cityData.Religions) > 0) then
												for _, beliefIndex in ipairs(cityData.BeliefsOfDominantReligion) do
													local beliefType = GameInfo.Beliefs[beliefIndex].BeliefType;
													for belief in GameInfo.BeliefModifiers() do
														if belief.BeliefType == beliefType then
															table.insert(modifierIDs, belief.ModifierID);
														end
													end
												end
											end

											if(#modifierIDs > 0) then
												for i=#modifierIDs, 1, -1 do
													if(string.find(modifierIDs[i], "ALLOW_")) then
														modifierIDs[i] = string.gsub(modifierIDs[i], "ALLOW", "BUILDING");
														if(row.BuildingType == string.gsub(modifierIDs[i], "ALLOW", "BUILDING")) then
															doShow = true;
														end
													end
												end
											end
										end
									end

									break;
								end
							end
						end

						if(not prereqInQueue) then doShow = false; end
					end

					-- Check for river adjacency requirement
					if (row.RequiresAdjacentRiver and not cityPlot:IsRiver()) then
						doShow = false;
					end

					-- Check for wall obsolescence
					if(row.OuterDefenseHitPoints and pPlayer:GetCulture():HasCivic(GameInfo.Civics["CIVIC_CIVIL_ENGINEERING"].Index)) then
						doShow = false;
					end

					-- Check for internal only buildings
					if(row.InternalOnly) then doShow = false end

					-- Check if it's been built already
					if(hasPrereqTech and hasPrereqCivic and isPrereqDistrictInQueue and doShow) then
						for _, district in ipairs(cityData.BuildingsAndDistricts) do
							if district.isBuilt then
								local match = false;

								for _,building in ipairs(district.Buildings) do
									if(building.Name == Locale.Lookup(row.Name)) then
										if(building.isBuilt and not building.isPillaged) then
											doShow = false;
										else
											doShow = true;
										end

										match = true;
										break;
									end
								end

								if(match) then break; end
							end
						end
					else
						doShow = false;
					end
				end

				if not row.MustPurchase and ( buildQueue:CanProduce( row.Hash, true ) or (doShow and not row.IsWonder) ) then
					local isCanStart, results			 = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled			:boolean = false;

					if(row.IsWonder or not doShow) then
						isDisabled = not isCanStart;
					end

					local allReasons			 :string = ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip 				 :string = ToolTipHelper.GetBuildingToolTip( row.Hash, playerID, selectedCity ) .. allReasons;

					local iProductionCost		:number = buildQueue:GetBuildingCost( row.Index );
					local iProductionProgress	:number = buildQueue:GetBuildingProgress( row.Index );

					if(disabledTooltip) then
						isDisabled = true;
						if(not string.find(sToolTip, "COLOR:Red")) then
							sToolTip = sToolTip .. "[NEWLINE][NEWLINE][COLOR:Red]" .. disabledTooltip .. "[ENDCOLOR]";
						end
					end

					sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

					local iPrereqDistrict = "";
					if row.PrereqDistrict ~= nil then
						iPrereqDistrict = row.PrereqDistrict;
					end

					table.insert( new_data.BuildingItems, {
						Type			= row.BuildingType,
						Name			= row.Name,
						ToolTip			= sToolTip,
						Hash			= row.Hash,
						Kind			= row.Kind,
						TurnsLeft		= buildQueue:GetTurnsLeft( row.Hash ),
						Disabled		= isDisabled,
						Repair			= cityBuildings:IsPillaged( row.Hash ),
						Cost			= iProductionCost,
						Progress		= iProductionProgress,
						IsWonder		= row.IsWonder,
						PrereqDistrict	= iPrereqDistrict }
					);
				end

				-- Can it be purchased with gold?
				if row.PurchaseYield == "YIELD_GOLD" then
					local isAllowed, kBldg = ComposeBldgForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
					if isAllowed then
						table.insert( new_data.BuildingPurchases, kBldg );
					end
				end
				-- Can it be purchased with faith?
				if row.PurchaseYield == "YIELD_FAITH" or cityGold:IsBuildingFaithPurchaseEnabled( row.Hash ) then
					local isAllowed, kBldg = ComposeBldgForPurchase( row, selectedCity, "YIELD_FAITH", playerReligion, "LOC_BUILDING_INSUFFICIENT_FAITH" );
					if isAllowed then
						table.insert( new_data.BuildingPurchases, kBldg );
					end
				end
			end

			for row in GameInfo.Units() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end
				-- Can it be built normally?
				if not row.MustPurchase and buildQueue:CanProduce( row.Hash, true ) then
					local isCanProduceExclusion, results	 = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled				:boolean = not isCanProduceExclusion;
					local sAllReasons				 :string = ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip					 :string = ToolTipHelper.GetUnitToolTip( row.Hash ) .. sAllReasons;

					local nProductionCost		:number = buildQueue:GetUnitCost( row.Index );
					local nProductionProgress	:number = buildQueue:GetUnitProgress( row.Index );
					sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

					local kUnit :table = {
						Type				= row.UnitType,
						Name				= row.Name,
						ToolTip				= sToolTip,
						Hash				= row.Hash,
						Kind				= row.Kind,
						TurnsLeft			= buildQueue:GetTurnsLeft( row.Hash ),
						Disabled			= isDisabled,
						Civilian			= row.FormationClass == "FORMATION_CLASS_CIVILIAN",
						Cost				= nProductionCost,
						Progress			= nProductionProgress,
						Corps				= false,
						CorpsCost			= 0,
						CorpsTurnsLeft		= 1,
						CorpsTooltip		= "",
						CorpsName			= "",
						Army				= false,
						ArmyCost			= 0,
						ArmyTurnsLeft		= 1,
						ArmyTooltip			= "",
						ArmyName			= "",
						ReligiousStrength	= row.ReligiousStrength
					};

					-- Should we present options for building Corps or Army versions?
					if results ~= nil then
						if results[CityOperationResults.CAN_TRAIN_CORPS] then
							kUnit.Corps			= true;
							kUnit.CorpsCost		= buildQueue:GetUnitCorpsCost( row.Index );
							kUnit.CorpsTurnsLeft	= buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
							kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( row.Name, row.Domain, nProductionProgress, kUnit.CorpsCost );
						end
						if results[CityOperationResults.CAN_TRAIN_ARMY] then
							kUnit.Army			= true;
							kUnit.ArmyCost		= buildQueue:GetUnitArmyCost( row.Index );
							kUnit.ArmyTurnsLeft	= buildQueue:GetTurnsLeft( row.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
							kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( row.Name, row.Domain, nProductionProgress, kUnit.ArmyCost );
						end
					end

					table.insert(new_data.UnitItems, kUnit );
				end

				-- Can it be purchased with gold?
				if row.PurchaseYield == "YIELD_GOLD" then
					local isAllowed, kUnit = ComposeUnitForPurchase( row, selectedCity, "YIELD_GOLD", playerTreasury, "LOC_BUILDING_INSUFFICIENT_FUNDS" );
					if isAllowed then
						table.insert( new_data.UnitPurchases, kUnit );
					end
				end
				-- Can it be purchased with faith?
				if row.PurchaseYield == "YIELD_FAITH" or cityGold:IsUnitFaithPurchaseEnabled( row.Hash ) then
					local isAllowed, kUnit = ComposeUnitForPurchase( row, selectedCity, "YIELD_FAITH", playerReligion, "LOC_BUILDING_INSUFFICIENT_FAITH" );
					if isAllowed then
						table.insert( new_data.UnitPurchases, kUnit );
					end
				end
			end

			for row in GameInfo.Projects() do
				if row.Hash == currentProductionHash then
					new_data.CurrentProduction = row.Name;
				end

				if buildQueue:CanProduce( row.Hash, true ) and not (row.MaxPlayerInstances and IsHashInAnyQueue(row.Hash)) then
					local isCanProduceExclusion, results = buildQueue:CanProduce( row.Hash, false, true );
					local isDisabled			:boolean = not isCanProduceExclusion;

					local allReasons		:string	= ComposeFailureReasonStrings( isDisabled, results );
					local sToolTip			:string = ToolTipHelper.GetProjectToolTip( row.Hash ) .. allReasons;

					local iProductionCost		:number = buildQueue:GetProjectCost( row.Index );
					local iProductionProgress	:number = buildQueue:GetProjectProgress( row.Index );
					sToolTip = sToolTip .. ComposeProductionCostString( iProductionProgress, iProductionCost );

					table.insert(new_data.ProjectItems, {
						Type			= row.ProjectType,
						Name			= row.Name,
						ToolTip			= sToolTip,
						Hash			= row.Hash,
						Kind			= row.Kind,
						TurnsLeft		= buildQueue:GetTurnsLeft( row.ProjectType ),
						Disabled		= isDisabled,
						Cost			= iProductionCost,
						Progress		= iProductionProgress
					});
				end
			end

			View(new_data, persistCollapse);
			ResizeQueueWindow();
			SaveQueues();
		end
	end

	-- ===========================================================================
	function ShowHideDisabled()
		--Controls.HideDisabled:SetSelected(showDisabled);
		showDisabled = not showDisabled;
		Refresh();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelChooseProduction()
		if (ContextPtr:IsHidden()) then
			Refresh();
		else
			if (m_tabs.selectedControl ~= m_productionTab) then
				m_tabs.SelectTab(m_productionTab);
			end
		end
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnNotificationPanelChooseProduction()
			if ContextPtr:IsHidden() then
			Open();

		--else																--TESTING TO SEE IF THIS FIXES OUR TUTORIAL BUG.
		--	if Controls.PauseDismissWindow:IsStopped() then
		--		Close();
		--	else
		--		Controls.PauseDismissWindow:Stop();
		--		Open();
		--	end
		end
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelChoosePurchase()
		if (ContextPtr:IsHidden()) then
			Refresh();
			OnTabChangePurchase();
			m_tabs.SelectTab(m_purchaseTab);
		else
			if (m_tabs.selectedControl ~= m_purchaseTab) then
				OnTabChangePurchase();
				m_tabs.SelectTab(m_purchaseTab);
			end
		end
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelChoosePurchaseFaith()
		if (ContextPtr:IsHidden()) then
			Refresh();
			OnTabChangePurchaseFaith();
			m_tabs.SelectTab(m_faithTab);
		else
			if (m_tabs.selectedControl ~= m_faithTab) then
				OnTabChangePurchaseFaith();
				m_tabs.SelectTab(m_faithTab);
			end
		end
	end

	-- ===========================================================================
	--	LUA Event
	--	Outside source is signaling production should be closed if open.
	-- ===========================================================================
	function OnProductionClose()
		if not ContextPtr:IsHidden() then
			Close();
		end
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city banner (anchored to world view)
	-- ===========================================================================
	function OnCityBannerManagerProductionToggle()
		m_isQueueMode = false;
		if(ContextPtr:IsHidden()) then
			Open();
		else
		end
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city information panel
	-- ===========================================================================
	function OnCityPanelProductionOpen()
		m_isQueueMode = false;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city information panel - Purchase with faith check
	-- ===========================================================================
	function OnCityPanelPurchaseFaithOpen()
		m_isQueueMode = false;
		Open();
		m_tabs.SelectTab(m_faithTab);
	end

	-- ===========================================================================
	--	LUA Event
	--	Production opened from city information panel - Purchase with gold check
	-- ===========================================================================
	function OnCityPanelPurchaseGoldOpen()
		m_isQueueMode = false;
		Open();
		m_tabs.SelectTab(m_purchaseTab);
	end
	-- ===========================================================================
	--	LUA Event
	--	Production opened from a placement
	-- ===========================================================================
	function OnStrategicViewMapPlacementProductionOpen()
		m_isQueueMode = false;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnTutorialProductionOpen()
		m_isQueueMode = false;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnProductionOpenForQueue()
		m_isQueueMode = true;
		Open();
	end

	-- ===========================================================================
	--	LUA Event
	-- ===========================================================================
	function OnCityPanelPurchasePlot()
		Close();
	end

	-- ===========================================================================
	--	LUA Event
	--	Set cached values back after a hotload.
	-- ===========================================================================
	function OnGameDebugReturn( context:string, contextTable:table )
		if context ~= RELOAD_CACHE_ID then return; end
		m_isQueueMode = contextTable["m_isQueueMode"];
		local isHidden:boolean = contextTable["isHidden"];
		if not isHidden then
			Refresh();
		end
	end

	-- ===========================================================================
	--	Keyboard INPUT Up Handler
	-- ===========================================================================
	function KeyUpHandler( key:number )
		if (key == Keys.VK_ESCAPE) then Close(); return true; end
		if (key == Keys.VK_CONTROL) then m_isCONTROLpressed = false; return true; end
		return false;
	end

	-- ===========================================================================
	--	Keyboard INPUT Down Handler
	-- ===========================================================================
	function KeyDownHandler( key:number )
		if (key == Keys.VK_CONTROL) then m_isCONTROLpressed = true; return true; end
		return false;
	end

	-- ===========================================================================
	--	UI Event
	-- ===========================================================================
	function OnInputHandler( pInputStruct:table )
		local uiMsg = pInputStruct:GetMessageType();
		if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end;
		if uiMsg == KeyEvents.KeyDown then return KeyDownHandler( pInputStruct:GetKey() ); end;
		return false;
	end

	-- ===========================================================================
	--	UI Event
	-- ===========================================================================
	function OnInit( isReload:boolean )
		if isReload then
			LuaEvents.GameDebug_GetValues( RELOAD_CACHE_ID );
		end
	end

	-- ===========================================================================
	--	UI Event
	-- ===========================================================================
	function OnShutdown()
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "m_isQueueMode", m_isQueueMode );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "prodQueue", prodQueue );
		LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID,  "isHidden",		ContextPtr:IsHidden() );
	end


	-- ===========================================================================
	-- ===========================================================================
	function Resize()
		--local contentSize = (m_maxProductionSize > m_maxPurchaseSize) and m_maxProductionSize or m_maxPurchaseSize;
		--contentSize = contentSize + WINDOW_HEADER_Y;
		--local w,h = UIManager:GetScreenSizeVal();
		--local maxAllowable = h - Controls.Window:GetOffsetY() - TOPBAR_Y;
		--local panelSizeY = (contentSize < maxAllowable) and contentSize or maxAllowable;
		--Controls.Window:SetSizeY(panelSizeY);
		--Controls.ProductionListScroll:SetSizeY(panelSizeY-Controls.WindowContent:GetOffsetY());
		--Controls.PurchaseListScroll:SetSizeY(panelSizeY-Controls.WindowContent:GetOffsetY());
		--Controls.DropShadow:SetSizeY(panelSizeY+100);
	end

	-- ===========================================================================
	-- ===========================================================================
	function CreateCorrectTabs()
		local MAX_TAB_LABEL_WIDTH = 273;
		local productionLabelX = Controls.ProductionTab:GetTextControl():GetSizeX();
		local purchaseLabelX = Controls.PurchaseTab:GetTextControl():GetSizeX();
		local purchaseFaithLabelX = Controls.PurchaseFaithTab:GetTextControl():GetSizeX();
		local tabAnimControl;
		local tabArrowControl;
		local tabSizeX;
		local tabSizeY;

		Controls.ProductionTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.PurchaseTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.PurchaseFaithTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.MiniProductionTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.MiniPurchaseTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	    Controls.MiniPurchaseFaithTab:RegisterCallback( Mouse.eMouseEnter,	function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

		Controls.MiniProductionTab:SetHide(true);
		Controls.MiniPurchaseTab:SetHide(true);
		Controls.MiniPurchaseFaithTab:SetHide(true);
		Controls.ProductionTab:SetHide(true);
		Controls.PurchaseTab:SetHide(true);
		Controls.PurchaseFaithTab:SetHide(true);
		Controls.MiniTabAnim:SetHide(true);
		Controls.MiniTabArrow:SetHide(true);
		Controls.TabAnim:SetHide(true);
		Controls.TabArrow:SetHide(true);

		local labelWidth = productionLabelX + purchaseLabelX;
		if GameCapabilities.HasCapability("CAPABILITY_FAITH") then
			labelWidth = labelWidth + purchaseFaithLabelX;
		end
		if(labelWidth > MAX_TAB_LABEL_WIDTH) then
			tabSizeX = 44;
			tabSizeY = 44;
			Controls.MiniProductionTab:SetHide(false);
			Controls.MiniPurchaseTab:SetHide(false);
			Controls.MiniPurchaseFaithTab:SetHide(false);
			Controls.MiniTabAnim:SetHide(false);
			Controls.MiniTabArrow:SetHide(false);
			m_productionTab = Controls.MiniProductionTab;
			m_purchaseTab	= Controls.MiniPurchaseTab;
			m_faithTab		= Controls.MiniPurchaseFaithTab;
			tabAnimControl	= Controls.MiniTabAnim;
			tabArrowControl = Controls.MiniTabArrow;
		else
			tabSizeX = 42;
			tabSizeY = 34;
			Controls.ProductionTab:SetHide(false);
			Controls.PurchaseTab:SetHide(false);
			Controls.PurchaseFaithTab:SetHide(false);
			Controls.TabAnim:SetHide(false);
			Controls.TabArrow:SetHide(false);
			m_productionTab = Controls.ProductionTab;
			m_purchaseTab	= Controls.PurchaseTab;
			m_faithTab		= Controls.PurchaseFaithTab;
			tabAnimControl	= Controls.TabAnim;
			tabArrowControl = Controls.TabArrow;
		end
		m_tabs = CreateTabs( Controls.TabRow, tabSizeX, tabSizeY, 0xFF331D05 );
		m_tabs.AddTab( m_productionTab,	OnTabChangeProduction );
		if GameCapabilities.HasCapability("CAPABILITY_GOLD") then
			m_tabs.AddTab( m_purchaseTab,	OnTabChangePurchase );
		else
			Controls.PurchaseTab:SetHide(true);
			Controls.MiniPurchaseTab:SetHide(true);
		end
		if GameCapabilities.HasCapability("CAPABILITY_FAITH") then
			m_tabs.AddTab( m_faithTab,	OnTabChangePurchaseFaith );
		else
			Controls.MiniPurchaseFaithTab:SetHide(true);
			Controls.PurchaseFaithTab:SetHide(true);
		end
		m_tabs.CenterAlignTabs(0);
		m_tabs.SelectTab( m_productionTab );
		m_tabs.AddAnimDeco(tabAnimControl, tabArrowControl);
	end


	--- =========================================================================================================
	--  ====================================== PRODUCTION QUEUE MOD FUNCTIONS ===================================
	--- =========================================================================================================

	--- =======================================================================================================
	--  === Production event handlers
	--- =======================================================================================================

	--- ===========================================================================
	--	Fires when a city's current production changes
	--- ===========================================================================
	function OnCityProductionChanged(playerID:number, cityID:number)
		Refresh();
	end

	function OnCityProductionUpdated( ownerPlayerID:number, cityID:number, eProductionType, eProductionObject)
		if(ownerPlayerID ~= Game.GetLocalPlayer()) then return end
		lastProductionCompletePerCity[cityID] = nil;
	end

	--- ===========================================================================
	--	Fires when a city's production is completed
	--  Note: This seems to sometimes fire more than once for a turn
	--- ===========================================================================
	function OnCityProductionCompleted(playerID, cityID, orderType, unitType, canceled, typeModifier)
		if (playerID ~= Game.GetLocalPlayer()) then return end;

		local pPlayer = Players[ playerID ];
		if (pPlayer == nil) then return end;

		local pCity = pPlayer:GetCities():FindID(cityID);
		if (pCity == nil) then return end;

		local currentTurn = Game.GetCurrentGameTurn();

		-- Only one item can be produced per turn per city
		if(lastProductionCompletePerCity[cityID] and lastProductionCompletePerCity[cityID] == currentTurn) then
			return;
		end

		if(prodQueue[cityID] and prodQueue[cityID][1]) then
			-- Check that the production is actually completed
			local productionInfo = GetProductionInfoOfCity(pCity, prodQueue[cityID][1].entry.Hash);
			local pDistricts = pCity:GetDistricts();
			local pBuildings = pCity:GetBuildings();
			local isComplete = false;

			if(prodQueue[cityID][1].type == PRODUCTION_TYPE.BUILDING or prodQueue[cityID][1].type == PRODUCTION_TYPE.PLACED) then
				if(GameInfo.Districts[prodQueue[cityID][1].entry.Hash] and pDistricts:HasDistrict(GameInfo.Districts[prodQueue[cityID][1].entry.Hash].Index, true)) then
					isComplete = true;
				elseif(GameInfo.Buildings[prodQueue[cityID][1].entry.Hash] and pBuildings:HasBuilding(GameInfo.Buildings[prodQueue[cityID][1].entry.Hash].Index)) then
					isComplete = true;
				elseif(productionInfo.PercentComplete >= 1) then
					isComplete = true;
				end

				if(not isComplete) then
					return;
				end
			end

			-- PQ: Experimental
			local productionType = prodQueue[cityID][1].type;
			if(orderType == 0) then
				if(productionType == PRODUCTION_TYPE.UNIT or productionType == PRODUCTION_TYPE.CORPS or productionType == PRODUCTION_TYPE.ARMY) then
					if(GameInfo.Units[prodQueue[cityID][1].entry.Hash].Index == unitType) then
						isComplete = true;
					end
				end
			elseif(orderType == 1) then
				-- Building/wonder
				if(productionType == PRODUCTION_TYPE.BUILDING or productionType == PRODUCTION_TYPE.PLACED) then
					local buildingInfo = GameInfo.Buildings[prodQueue[cityID][1].entry.Hash];
					if(buildingInfo and buildingInfo.Index == unitType) then
						isComplete = true;
					end
				end

					-- Check if this building is in our queue at all
				if(not isComplete and IsHashInQueue(pCity, GameInfo.Buildings[unitType].Hash)) then
					local removeIndex = GetIndexOfHashInQueue(pCity, GameInfo.Buildings[unitType].Hash);
					RemoveFromQueue(cityID, removeIndex, true);

					if(removeIndex == 1) then
						BuildFirstQueued(pCity);
					else
						Refresh(true);
					end

					SaveQueues();
					return;
				end
			elseif(orderType == 2) then
				-- District
				if(productionType == PRODUCTION_TYPE.PLACED) then
					local districtInfo = GameInfo.Districts[prodQueue[cityID][1].entry.Hash];
					if(districtInfo and districtInfo.Index == unitType) then
						isComplete = true;
					end
				end
			elseif(orderType == 3) then
				-- Project
				if(productionType == PRODUCTION_TYPE.PROJECT) then
					local projectInfo = GameInfo.Projects[prodQueue[cityID][1].entry.Hash];
					if(projectInfo and projectInfo.Index == unitType) then
						isComplete = true;
					end
				end
			end

			if(not isComplete) then
				Refresh(true);
				return;
			end

			table.remove(prodQueue[cityID], 1);
			if(#prodQueue[cityID] > 0) then
				BuildFirstQueued(pCity);
			end

			lastProductionCompletePerCity[cityID] = currentTurn;
			SaveQueues();
		end
	end


	--- =======================================================================================================
	--  === Load/Save
	--- =======================================================================================================

	--- ==========================================================================
	--  Updates the PlayerConfiguration with all ProductionQueue data
	--- ==========================================================================
	function SaveQueues()
		PlayerConfigurations[Game.GetLocalPlayer()]:SetValue("ZenProductionQueue", DataDumper(prodQueue, "prodQueue"));
	end

	--- ==========================================================================
	--  Loads ProductionQueue data from PlayerConfiguration, and populates the
	--  queue with current production information if saved info not present
	--- ==========================================================================
	function LoadQueues()
		local localPlayerID = Game.GetLocalPlayer();
		if(PlayerConfigurations[localPlayerID]:GetValue("ZenProductionQueue") ~= nil) then
			loadstring(PlayerConfigurations[localPlayerID]:GetValue("ZenProductionQueue"))();
		end

		if(not prodQueue) then
			prodQueue = {};
		end

	 	local player = Players[localPlayerID];
	 	local cities = player:GetCities();

	 	for j, city in cities:Members() do
	 		local cityID = city:GetID();
	 		local buildQueue = city:GetBuildQueue();
	 		local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
	 		local plotID = -1;

	 		if(not prodQueue[cityID]) then
	 			prodQueue[cityID] = {};
	 		end

	 		if(not prodQueue[cityID][1] and currentProductionHash ~= 0) then
	 			-- Determine the type of the item
	 			local currentType = 0;
	 			local productionInfo = GetProductionInfoOfCity(city, currentProductionHash);
	 			productionInfo.Hash = currentProductionHash;

	 			if(productionInfo.Type == "UNIT") then
	 				currentType = buildQueue:GetCurrentProductionTypeModifier() + 2;
				elseif(productionInfo.Type == "BUILDING") then
					if(GameInfo.Buildings[currentProductionHash].MaxWorldInstances == 1) then
						currentType = PRODUCTION_TYPE.PLACED;

						local pCityBuildings	:table = city:GetBuildings();
						local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( city );
						if (kCityPlots ~= nil) then
							for _,plot in pairs(kCityPlots) do
								local kPlot:table =  Map.GetPlotByIndex(plot);
								local wonderType = kPlot:GetWonderType();
								if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == GameInfo.Buildings[currentProductionHash].BuildingType) then
									plotID = plot;
								end
							end
						end
					else
						currentType = PRODUCTION_TYPE.BUILDING;
					end
				elseif(productionInfo.Type == "DISTRICT") then
					currentType = PRODUCTION_TYPE.PLACED;
				elseif(productionInfo.Type == "PROJECT") then
					currentType = PRODUCTION_TYPE.PROJECT;
	 			end

	 			if(currentType == 0) then
	 				print("Could not find production type for hash: " .. currentProductionHash);
	 			end

	 			prodQueue[cityID][1] = {
	 				entry=productionInfo,
	 				type=currentType,
	 				plotID=plotID
	 			}

			elseif(currentProductionHash == 0) then
	 		end
		end

		-- Populate our table for building prerequisites
		for prereqRow in GameInfo.BuildingPrereqs() do
			buildingPrereqs[prereqRow.Building] = 1;
		end

		for building in GameInfo.MutuallyExclusiveBuildings() do
			mutuallyExclusiveBuildings[building.Building] = 1;
		end
	end


	--- =======================================================================================================
	--  === Queue information
	--- =======================================================================================================

	--- ===========================================================================
	--	Checks if there is a specific building hash in a city's Production Queue
	--- ===========================================================================
	function IsBuildingInQueue(city, buildingHash)
		local cityID = city:GetID();

		if(prodQueue and #prodQueue[cityID] > 0) then
			for _, qi in pairs(prodQueue[cityID]) do
				if(qi.entry and qi.entry.Hash == buildingHash) then
					if(qi.type == PRODUCTION_TYPE.BUILDING or qi.type == PRODUCTION_TYPE.PLACED) then
						return true;
					end
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Checks if there is a specific wonder hash in all Production Queues
	--- ===========================================================================
	function IsWonderInQueue(wonderHash)
		for _,city in pairs(prodQueue) do
			for _, qi in pairs(city) do
				if(qi.entry and qi.entry.Hash == wonderHash) then
					if(qi.type == PRODUCTION_TYPE.PLACED) then
						return true;
					end
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Checks if there is a specific hash in all Production Queues
	--- ===========================================================================
	function IsHashInAnyQueue(hash)
		for _,city in pairs(prodQueue) do
			for _, qi in pairs(city) do
				if(qi.entry and qi.entry.Hash == hash) then
					return true;
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Checks if there is a specific item hash in a city's Production Queue
	--- ===========================================================================
	function IsHashInQueue(city, hash)
		local cityID = city:GetID();

		if(prodQueue and #prodQueue[cityID] > 0) then
			for i, qi in pairs(prodQueue[cityID]) do
				if(qi.entry and qi.entry.Hash == hash) then
					return true;
				end
			end
		end
		return false;
	end

	--- ===========================================================================
	--	Returns the first instance of a hash in a city's Production Queue
	--- ===========================================================================
	function GetIndexOfHashInQueue(city, hash)
		local cityID = city:GetID();

		if(prodQueue and #prodQueue[cityID] > 0) then
			for i, qi in pairs(prodQueue[cityID]) do
				if(qi.entry and qi.entry.Hash == hash) then
					return i;
				end
			end
		end
		return nil;
	end

	--- ===========================================================================
	--	Get the total number of districts (requiring population)
	--  in a city's Production Queue still requiring placement
	--- ===========================================================================
	function GetNumDistrictsInCityQueue(city)
		local numDistricts = 0;
		local cityID = city:GetID();
		local pBuildQueue = city:GetBuildQueue();

		if(#prodQueue[cityID] > 0) then
			for _,qi in pairs(prodQueue[cityID]) do
				if(GameInfo.Districts[qi.entry.Hash] and GameInfo.Districts[qi.entry.Hash].RequiresPopulation) then
					if (not pBuildQueue:HasBeenPlaced(qi.entry.Hash)) then
						numDistricts = numDistricts + 1;
					end
				end
			end
		end

		return numDistricts;
	end

	--- =============================================================================
	--  [Doing it this way is ridiculous and hacky but I am tired; Please forgive me]
	--  Checks the Production Queue for matching reserved plots
	--- =============================================================================
	GameInfo.Districts['DISTRICT_CITY_CENTER'].IsPlotValid = function(pCity, plotID)
		local cityID = pCity:GetID();

		if(#prodQueue[cityID] > 0) then
			for j,item in ipairs(prodQueue[cityID]) do
				if(item.plotID == plotID) then
					return false;
				end
			end
		end
		return true;
	end


	--- =======================================================================================================
	--  === Drag and Drop
	--- =======================================================================================================

	--- ==========================================================================
	--  Creates a valid drop area for the queue item drag and drop system
	--- ==========================================================================
	function BuildProductionQueueDropArea( control:table, num:number, label:string )
		AddDropArea( control, num, m_kProductionQueueDropAreas );
	end

	--- ===========================================================================
	--	Fires when picking up an item in the Production Queue
	--- ===========================================================================
	function OnDownInQueue( dragStruct:table, queueListing:table, index:number )
		UI.PlaySound("Play_UI_Click");
	end

	--- ===========================================================================
	--	Fires when dropping an item in the Production Queue
	--- ===========================================================================
	function OnDropInQueue( dragStruct:table, queueListing:table, index:number )
		local dragControl:table			= dragStruct:GetControl();
		local x:number,y:number			= dragControl:GetScreenOffset();
		local width:number,height:number= dragControl:GetSizeVal();
		local dropArea:DropAreaStruct	= GetDropArea(x,y,width,height,m_kProductionQueueDropAreas);

		if dropArea ~= nil and dropArea.id ~= index then
			local city = UI.GetHeadSelectedCity();
			local cityID = city:GetID();

			MoveQueueIndex(cityID, index, dropArea.id);
			dragControl:StopSnapBack();
			if(index == 1 or dropArea.id == 1) then
				BuildFirstQueued(city);
			else
				Refresh(true);
			end
		end
	end

	--- =======================================================================================================
	--  === Queueing/Building
	--- =======================================================================================================

	--- ==========================================================================
	--  Adds unit of given type to the Production Queue and builds it if requested
	--- ==========================================================================
	function QueueUnitOfType(city, unitEntry, unitType, skipToFront)
		local cityID = city:GetID();
		local index = 1;

		if(not prodQueue[cityID]) then prodQueue[cityID] = {}; end
		if(not skipToFront) then index = #prodQueue[cityID] + 1; end

		table.insert(prodQueue[cityID], index, {
			entry=unitEntry,
			type=unitType,
			plotID=-1
			});

		if(#prodQueue[cityID] == 1 or skipToFront) then
			BuildFirstQueued(city);
		else
			Refresh(true);
		end

	    UI.PlaySound("Confirm_Production");
	end

	--- ==========================================================================
	--  Adds unit to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueUnit(city, unitEntry, skipToFront)
		QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.UNIT, skipToFront);
	end

	--- ==========================================================================
	--  Adds corps to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueUnitCorps(city, unitEntry, skipToFront)
		QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.CORPS, skipToFront);
	end

	--- ==========================================================================
	--  Adds army to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueUnitArmy(city, unitEntry, skipToFront)
		QueueUnitOfType(city, unitEntry, PRODUCTION_TYPE.ARMY, skipToFront);
	end

	--- ==========================================================================
	--  Adds building to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueBuilding(city, buildingEntry, skipToFront)
		local building			:table		= GameInfo.Buildings[buildingEntry.Type];
		local bNeedsPlacement	:boolean	= building.RequiresPlacement;

		local pBuildQueue = city:GetBuildQueue();
		if (pBuildQueue:HasBeenPlaced(buildingEntry.Hash)) then
			bNeedsPlacement = false;
		end

		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

		if (bNeedsPlacement) then
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_BUILDING_TYPE] = buildingEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.BUILDING_PLACEMENT, tParameters);
		else
			local cityID = city:GetID();
			local plotID = -1;
			local buildingType = PRODUCTION_TYPE.BUILDING;

			if(not prodQueue[cityID]) then
				prodQueue[cityID] = {};
			end

			if(building.RequiresPlacement) then
				local pCityBuildings	:table = city:GetBuildings();
				local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( city );
				if (kCityPlots ~= nil) then
					for _,plot in pairs(kCityPlots) do
						local kPlot:table =  Map.GetPlotByIndex(plot);
						local wonderType = kPlot:GetWonderType();
						if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == building.BuildingType) then
							plotID = plot;
							buildingType = PRODUCTION_TYPE.PLACED;
						end
					end
				end
			end

			table.insert(prodQueue[cityID], {
				entry=buildingEntry,
				type=buildingType,
				plotID=plotID
				});

			if(skipToFront) then
				if(MoveQueueIndex(cityID, #prodQueue[cityID], 1) ~= 0) then
					Refresh(true);
				else
					BuildFirstQueued(city);
				end
			elseif(#prodQueue[cityID] == 1) then
				BuildFirstQueued(city);
			else
				Refresh(true);
			end

	        UI.PlaySound("Confirm_Production");
		end
	end

	--- ==========================================================================
	--  Adds district to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueDistrict(city, districtEntry, skipToFront)
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);

		local district			:table		= GameInfo.Districts[districtEntry.Type];
		local bNeedsPlacement	:boolean	= district.RequiresPlacement;
		local pBuildQueue		:table		= city:GetBuildQueue();

		if (pBuildQueue:HasBeenPlaced(districtEntry.Hash)) then
			bNeedsPlacement = false;
		end

		if (bNeedsPlacement) then
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;
			UI.SetInterfaceMode(InterfaceModeTypes.DISTRICT_PLACEMENT, tParameters);
		else
			local tParameters = {};
			tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE] = districtEntry.Hash;
			tParameters[CityOperationTypes.PARAM_INSERT_MODE] = CityOperationTypes.VALUE_EXCLUSIVE;

			local cityID = city:GetID();

			if(not prodQueue[cityID]) then
				prodQueue[cityID] = {};
			end

			local index = 1;
			if(not skipToFront) then index = #prodQueue[cityID] + 1; end

			table.insert(prodQueue[cityID], index, {
				entry=districtEntry,
				type=PRODUCTION_TYPE.PLACED,
				plotID=-1,
				tParameters=tParameters
				});

			if(#prodQueue[cityID] == 1 or skipToFront) then
				BuildFirstQueued(city);
			else
				Refresh(true);
			end
	        UI.PlaySound("Confirm_Production");
		end
	end

	--- ==========================================================================
	--  Adds project to the Production Queue and builds if requested
	--- ==========================================================================
	function QueueProject(city, projectEntry, skipToFront)
		local cityID = city:GetID();

		if(not prodQueue[cityID]) then
			prodQueue[cityID] = {};
		end

		local index = 1;
		if(not skipToFront) then index = #prodQueue[cityID] + 1; end

		table.insert(prodQueue[cityID], index, {
			entry=projectEntry,
			type=PRODUCTION_TYPE.PROJECT,
			plotID=-1
			});

		if(#prodQueue[cityID] == 1 or skipToFront) then
				BuildFirstQueued(city);
		else
			Refresh(true);
		end

	    UI.PlaySound("Confirm_Production");
	end

	--- ===========================================================================
	--	Check if removing an index would result in an empty queue
	--- ===========================================================================
	function CanRemoveFromQueue(cityID, index)
		local totalItemsToRemove = 1;

		if(prodQueue[cityID] and #prodQueue[cityID] > 1 and prodQueue[cityID][index]) then
			local destIndex = MoveQueueIndex(cityID, index, #prodQueue[cityID], true);
			if(destIndex > 0) then
				totalItemsToRemove = totalItemsToRemove + 1;
				CanRemoveFromQueue(cityID, destIndex + 1);
			end
		end

		if(totalItemsToRemove == #prodQueue[cityID]) then
			return false;
		else
			return true;
		end
	end

	--- ===========================================================================
	--	Remove a specific index from a city's Production Queue
	--- ===========================================================================
	function RemoveFromQueue(cityID, index, force)
		if(prodQueue[cityID] and (#prodQueue[cityID] > 1 or force) and prodQueue[cityID][index]) then
			local destIndex = MoveQueueIndex(cityID, index, #prodQueue[cityID]);
			if(destIndex > 0) then
				-- There was a conflict
				RemoveFromQueue(cityID, destIndex + 1);
				table.remove(prodQueue[cityID], destIndex);
			else
				table.remove(prodQueue[cityID], #prodQueue[cityID]);
			end
			return true;
		end
		return false;
	end

	--- ==========================================================================
	--  Directly requests the city to build a placed district/wonder using
	--  tParameters provided from the StrategicView callback event
	--- ==========================================================================
	function BuildPlaced(city, tParameters)
		-- Check if we still have enough population for a district we're about to place
		local districtHash = tParameters[CityOperationTypes.PARAM_DISTRICT_TYPE];
		if(districtHash) then
			local pCityDistricts = city:GetDistricts();
			local numDistricts = pCityDistricts:GetNumZonedDistrictsRequiringPopulation();
			local numPossibleDistricts = pCityDistricts:GetNumAllowedDistrictsRequiringPopulation();

			if(GameInfo.Districts[districtHash] and GameInfo.Districts[districtHash].RequiresPopulation and numDistricts <= numPossibleDistricts) then
				if(GetNumDistrictsInCityQueue(city) + numDistricts > numPossibleDistricts) then
					RemoveFromQueue(city:GetID(), 1);
					BuildFirstQueued(city);
					return;
				end
			end
		end

		CityManager.RequestOperation(city, CityOperationTypes.BUILD, tParameters);
	end

	--- ==========================================================================
	--  Builds the first item in the Production Queue
	--- ==========================================================================
	function BuildFirstQueued(pCity)
		local cityID = pCity:GetID();
		if(prodQueue[cityID][1]) then
			if(prodQueue[cityID][1].type == PRODUCTION_TYPE.BUILDING) then
				BuildBuilding(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.UNIT) then
				BuildUnit(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.ARMY) then
				BuildUnitArmy(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.CORPS) then
				BuildUnitCorps(pCity, prodQueue[cityID][1].entry);
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.PLACED) then
				if(not prodQueue[cityID][1].tParameters) then
					if(GameInfo.Buildings[prodQueue[cityID][1].entry.Hash]) then
						BuildBuilding(pCity, prodQueue[cityID][1].entry);
					else
						ZoneDistrict(pCity, prodQueue[cityID][1].entry);
					end
				else
					BuildPlaced(pCity, prodQueue[cityID][1].tParameters);
				end
			elseif(prodQueue[cityID][1].type == PRODUCTION_TYPE.PROJECT) then
				AdvanceProject(pCity, prodQueue[cityID][1].entry);
			end
		else
			Refresh(true);
		end
	end

	--- ============================================================================
	--  Lua Event
	--  This is fired when a district or wonder plot has been selected and confirmed
	--- ============================================================================
	function OnStrategicViewMapPlacementProductionClose(tProductionQueueParameters)
		local cityID = tProductionQueueParameters.pSelectedCity:GetID();
		local entry = GetProductionInfoOfCity(tProductionQueueParameters.pSelectedCity, tProductionQueueParameters.buildingHash);
		entry.Hash = tProductionQueueParameters.buildingHash;

		if(not prodQueue[cityID]) then prodQueue[cityID] = {}; end

		local index = 1;
		if(not nextDistrictSkipToFront) then index = #prodQueue[cityID] + 1; end

		table.insert(prodQueue[cityID], index, {
			entry=entry,
			type=PRODUCTION_TYPE.PLACED,
			plotID=tProductionQueueParameters.plotId,
			tParameters=tProductionQueueParameters.tParameters
			});

		if(nextDistrictSkipToFront or #prodQueue[cityID] == 1) then BuildFirstQueued(tProductionQueueParameters.pSelectedCity); end
		Refresh(true);
		UI.PlaySound("Confirm_Production");
	end

	--- ===========================================================================
	--	Move a city's queue item from one index to another
	--- ===========================================================================
	function MoveQueueIndex(cityID, sourceIndex, destIndex, noMove)
		local direction = -1;
		local actualDest = 0;

		local sourceInfo = prodQueue[cityID][sourceIndex];

		if(sourceIndex < destIndex) then direction = 1; end
		for i=sourceIndex, math.max(destIndex-direction, 1), direction do
			-- Each time we swap, we need to check that there isn't a prereq that would break
			if(sourceInfo.type == PRODUCTION_TYPE.BUILDING and prodQueue[cityID][i+direction].type == PRODUCTION_TYPE.PLACED) then
				local buildingInfo = GameInfo.Buildings[sourceInfo.entry.Hash];
				if(buildingInfo and buildingInfo.PrereqDistrict) then
					local districtInfo = GameInfo.Districts[prodQueue[cityID][i+direction].entry.Hash];
					if(districtInfo and (districtInfo.DistrictType == buildingInfo.PrereqDistrict or (GameInfo.DistrictReplaces[prodQueue[cityID][i+direction].entry.Hash] and GameInfo.DistrictReplaces[prodQueue[cityID][i+direction].entry.Hash].ReplacesDistrictType == buildingInfo.PrereqDistrict))) then
						actualDest = i;
						break;
					end
				end
			elseif(sourceInfo.type == PRODUCTION_TYPE.PLACED and prodQueue[cityID][i+direction].type == PRODUCTION_TYPE.BUILDING) then
				local buildingInfo = GameInfo.Buildings[prodQueue[cityID][i+direction].entry.Hash];
				local districtInfo = GameInfo.Districts[sourceInfo.entry.Hash];

				if(buildingInfo and buildingInfo.PrereqDistrict) then
					if(districtInfo and (districtInfo.DistrictType == buildingInfo.PrereqDistrict or (GameInfo.DistrictReplaces[sourceInfo.entry.Hash] and GameInfo.DistrictReplaces[sourceInfo.entry.Hash].ReplacesDistrictType == buildingInfo.PrereqDistrict))) then
						actualDest = i;
						break;
					end
				end
			elseif(sourceInfo.type == PRODUCTION_TYPE.BUILDING and prodQueue[cityID][i+direction].type == PRODUCTION_TYPE.BUILDING) then
				local destInfo = GameInfo.Buildings[prodQueue[cityID][i+direction].entry.Hash];
				local sourceBuildingInfo = GameInfo.Buildings[sourceInfo.entry.Hash];

				if(GameInfo.BuildingReplaces[destInfo.BuildingType]) then
					destInfo = GameInfo.Buildings[GameInfo.BuildingReplaces[destInfo.BuildingType].ReplacesBuildingType];
				end

				if(GameInfo.BuildingReplaces[sourceBuildingInfo.BuildingType]) then
					sourceBuildingInfo = GameInfo.Buildings[GameInfo.BuildingReplaces[sourceBuildingInfo.BuildingType].ReplacesBuildingType];
				end

				local halt = false;

				for prereqRow in GameInfo.BuildingPrereqs() do
					if(prereqRow.Building == sourceBuildingInfo.BuildingType) then
						if(destInfo.BuildingType == prereqRow.PrereqBuilding) then
							halt = true;
							actualDest = i;
							break;
						end
					end

					if(prereqRow.PrereqBuilding == sourceBuildingInfo.BuildingType) then
						if(destInfo.BuildingType == prereqRow.Building) then
							halt = true;
							actualDest = i;
							break;
						end
					end
				end

				if(halt == true) then break; end
			end

			if(not noMove) then
				prodQueue[cityID][i], prodQueue[cityID][i+direction] = prodQueue[cityID][i+direction], prodQueue[cityID][i];
			end
		end

		return actualDest;
	end

	--- ===========================================================================
	--	Check the entire queue for mandatory item upgrades
	--- ===========================================================================
	function CheckAndReplaceAllQueuesForUpgrades()
		local localPlayerId:number = Game.GetLocalPlayer();
		local player = Players[localPlayerId];

		if(player == nil) then
			return;
		end

	 	local cities = player:GetCities();

	 	for j, city in cities:Members() do
	 		CheckAndReplaceQueueForUpgrades(city);
	 	end
	end

	--- ===========================================================================
	--	Check a city's queue for items that must be upgraded or removed
	--  as per tech/civic knowledge
	--- ===========================================================================
	function CheckAndReplaceQueueForUpgrades(city)
		local playerID = Game.GetLocalPlayer();
		local pPlayer = Players[playerID];
		local pTech = pPlayer:GetTechs();
		local pCulture = pPlayer:GetCulture();
		local buildQueue = city:GetBuildQueue();
		local cityID = city:GetID();
		local pBuildings = city:GetBuildings();
		local civTypeName = PlayerConfigurations[playerID]:GetCivilizationTypeName();
		local removeUnits = {};

		if(not prodQueue[cityID]) then prodQueue[cityID] = {} end

		for i, qi in pairs(prodQueue[cityID]) do
			if(qi.type == PRODUCTION_TYPE.UNIT or qi.type == PRODUCTION_TYPE.CORPS or qi.type == PRODUCTION_TYPE.ARMY) then
				local unitUpgrades = GameInfo.UnitUpgrades[qi.entry.Hash];
				if(unitUpgrades) then
					local upgradeUnit = GameInfo.Units[unitUpgrades.UpgradeUnit];

					-- Check for unique units
					for unitReplaces in GameInfo.UnitReplaces() do
						if(unitReplaces.ReplacesUnitType == unitUpgrades.UpgradeUnit) then
							local match = false;

							for civTraits in GameInfo.CivilizationTraits() do
								if(civTraits.TraitType == "TRAIT_CIVILIZATION_" .. unitReplaces.CivUniqueUnitType and civTraits.CivilizationType == civTypeName) then
									upgradeUnit = GameInfo.Units[unitReplaces.CivUniqueUnitType];
									match = true;
									break;
								end
							end

							if(match) then break; end
						end
					end

					if(upgradeUnit) then
						local canUpgrade = true;

						if(upgradeUnit.PrereqTech and not pTech:HasTech(GameInfo.Technologies[upgradeUnit.PrereqTech].Index)) then
							canUpgrade = false;
						end
						if(upgradeUnit.PrereqCivic and not pCulture:HasCivic(GameInfo.Civics[upgradeUnit.PrereqCivic].Index)) then
							canUpgrade = false;
						end

						local canBuildNewUnit = buildQueue:CanProduce( upgradeUnit.Hash, false, true );

						-- Only auto replace if we CAN'T queue the old unit
						if(not buildQueue:CanProduce( qi.entry.Hash, true ) and canUpgrade and canBuildNewUnit) then
							local isCanProduceExclusion, results	 = buildQueue:CanProduce( upgradeUnit.Hash, false, true );
							local isDisabled				:boolean = not isCanProduceExclusion;
							local sAllReasons				 :string = ComposeFailureReasonStrings( isDisabled, results );
							local sToolTip					 :string = ToolTipHelper.GetUnitToolTip( upgradeUnit.Hash ) .. sAllReasons;

							local nProductionCost		:number = buildQueue:GetUnitCost( upgradeUnit.Index );
							local nProductionProgress	:number = buildQueue:GetUnitProgress( upgradeUnit.Index );
							sToolTip = sToolTip .. ComposeProductionCostString( nProductionProgress, nProductionCost );

							prodQueue[cityID][i].entry = {
								Type			= upgradeUnit.UnitType,
								Name			= upgradeUnit.Name,
								ToolTip			= sToolTip,
								Hash			= upgradeUnit.Hash,
								Kind			= upgradeUnit.Kind,
								TurnsLeft		= buildQueue:GetTurnsLeft( upgradeUnit.Hash ),
								Disabled		= isDisabled,
								Civilian		= upgradeUnit.FormationClass == "FORMATION_CLASS_CIVILIAN",
								Cost			= nProductionCost,
								Progress		= nProductionProgress,
								Corps			= false,
								CorpsCost		= 0,
								CorpsTurnsLeft	= 1,
								CorpsTooltip	= "",
								CorpsName		= "",
								Army			= false,
								ArmyCost		= 0,
								ArmyTurnsLeft	= 1,
								ArmyTooltip		= "",
								ArmyName		= ""
							};

							if results ~= nil then
								if results[CityOperationResults.CAN_TRAIN_CORPS] then
									kUnit.Corps			= true;
									kUnit.CorpsCost		= buildQueue:GetUnitCorpsCost( upgradeUnit.Index );
									kUnit.CorpsTurnsLeft	= buildQueue:GetTurnsLeft( upgradeUnit.Hash, MilitaryFormationTypes.CORPS_MILITARY_FORMATION );
									kUnit.CorpsTooltip, kUnit.CorpsName = ComposeUnitCorpsStrings( upgradeUnit.Name, upgradeUnit.Domain, nProductionProgress, kUnit.CorpsCost );
								end
								if results[CityOperationResults.CAN_TRAIN_ARMY] then
									kUnit.Army			= true;
									kUnit.ArmyCost		= buildQueue:GetUnitArmyCost( upgradeUnit.Index );
									kUnit.ArmyTurnsLeft	= buildQueue:GetTurnsLeft( upgradeUnit.Hash, MilitaryFormationTypes.ARMY_MILITARY_FORMATION );
									kUnit.ArmyTooltip, kUnit.ArmyName = ComposeUnitArmyStrings( upgradeUnit.Name, upgradeUnit.Domain, nProductionProgress, kUnit.ArmyCost );
								end
							end
						elseif(canUpgrade and not canBuildNewUnit) then
							-- Can't build the old or new unit. Probably missing a resource. Remove from queue.
							table.insert(removeUnits, i);
						end
					end
				else
					local canBuildUnit = buildQueue:CanProduce( qi.entry.Hash, false, true );
					if(not canBuildUnit) then
						table.insert(removeUnits, i);
					end
				end
			elseif(qi.type == PRODUCTION_TYPE.BUILDING or qi.type == PRODUCTION_TYPE.PLACED) then
				if(qi.entry.Repair == true and GameInfo.Buildings[qi.entry.Hash]) then
					local isPillaged = pBuildings:IsPillaged(GameInfo.Buildings[qi.entry.Hash].Index);
					if(not isPillaged) then
						-- Repair complete, remove from queue
						table.insert(removeUnits, i);
					end
				end

				-- Check if a queued wonder is still available
				if(GameInfo.Buildings[qi.entry.Hash] and GameInfo.Buildings[qi.entry.Hash].MaxWorldInstances == 1) then
					if(not buildQueue:CanProduce(qi.entry.Hash, true)) then
						table.insert(removeUnits, i);
					elseif(not IsCityPlotValidForWonderPlacement(city, qi.plotID, GameInfo.Buildings[qi.entry.Hash]) and not buildQueue:HasBeenPlaced(qi.entry.Hash)) then
						table.insert(removeUnits, i);
					end
				end
			end
		end

		if(#removeUnits > 0) then
			for i=#removeUnits, 1, -1 do
				local success = RemoveFromQueue(cityID, removeUnits[i]);
				if(success and removeUnits[i] == 1) then
					BuildFirstQueued(city);
				end
			end
		end
	end

	function IsCityPlotValidForWonderPlacement(city, plotID, wonder)
		if(not plotID or plotID == -1) then return true end
		if Map.GetPlotByIndex(plotID):CanHaveWonder(wonder.Index, city:GetOwner(), city:GetID()) then
			return true;
		else
			return false;
		end
	end

	--- =======================================================================================================
	--  === UI handling
	--- =======================================================================================================

	--- ==========================================================================
	--  Resize the Production Queue window to fit the items
	--- ==========================================================================
	function ResizeQueueWindow()
		Controls.QueueWindow:SetSizeY(1);
		local windowHeight = math.min(math.max(#prodQueue[UI.GetHeadSelectedCity():GetID()] * 32 + 38, 70), screenHeight-300);
		Controls.QueueWindow:SetSizeY(windowHeight);
		Controls.ProductionQueueListScroll:SetSizeY(windowHeight-38);
		Controls.ProductionQueueListScroll:CalculateSize();
	end

	--- ==========================================================================
	--  Slide-in/hide the Production Queue panel
	--- ==========================================================================
	function CloseQueueWindow()
		Controls.QueueSlideIn:Reverse();
		Controls.QueueWindowToggleDirection:SetText("<");
	end

	--- ==========================================================================
	--  Slide-out/show the Production Queue panel
	--- ==========================================================================
	function OpenQueueWindow()
		Controls.QueueSlideIn:SetToBeginning();
		Controls.QueueSlideIn:Play();
		Controls.QueueWindowToggleDirection:SetText(">");
	end

	--- ==========================================================================
	--  Toggle the visibility of the Production Queue panel
	--- ==========================================================================
	function ToggleQueueWindow()
		showStandaloneQueueWindow = not showStandaloneQueueWindow;

		if(showStandaloneQueueWindow) then
			OpenQueueWindow();
		else
			CloseQueueWindow();
		end
	end

	--- ===============================================================================
	--  Control Event
	--  Fires when the production panel has finished fading in
	--  Use this to, if it is toggled off, delay showing the Production Queue panel
	--  (and therefore toggle tab) unitl after the production panel is there to
	--  cover it up
	--- ===============================================================================
	function OnPanelFadeInComplete()
		if(not showStandaloneQueueWindow) then
			Controls.QueueAlphaIn:Play();
		end
	end

	--- ===========================================================================
	--	Recenter the camera over the selected city
	--  This is here for the sake of middle mouse clicking on a production item
	--  which ordinarily recenters the map to the cursor position
	--- ===========================================================================
	function RecenterCameraToSelectedCity()
		local kCity:table = UI.GetHeadSelectedCity();
		UI.LookAtPlot( kCity:GetX(), kCity:GetY() );
	end

	function ResetSelectedCityQueue()
		local selectedCity = UI.GetHeadSelectedCity();
		if(not selectedCity) then return end

		local cityID = selectedCity:GetID();
		if(not cityID) then return end

		local buildQueue = selectedCity:GetBuildQueue();
		local currentProductionHash = buildQueue:GetCurrentProductionTypeHash();
		local plotID = -1;

		if(prodQueue[cityID]) then prodQueue[cityID] = {}; end

		if(currentProductionHash ~= 0) then
			-- Determine the type of the item
			local currentType = 0;
			local productionInfo = GetProductionInfoOfCity(selectedCity, currentProductionHash);
			productionInfo.Hash = currentProductionHash;

			if(productionInfo.Type == "UNIT") then
				currentType = buildQueue:GetCurrentProductionTypeModifier() + 2;
			elseif(productionInfo.Type == "BUILDING") then
				if(GameInfo.Buildings[currentProductionHash].MaxWorldInstances == 1) then
					currentType = PRODUCTION_TYPE.PLACED;

					local pCityBuildings	:table = selectedCity:GetBuildings();
					local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( selectedCity );
					if (kCityPlots ~= nil) then
						for _,plot in pairs(kCityPlots) do
							local kPlot:table =  Map.GetPlotByIndex(plot);
							local wonderType = kPlot:GetWonderType();
							if(wonderType ~= -1 and GameInfo.Buildings[wonderType].BuildingType == GameInfo.Buildings[currentProductionHash].BuildingType) then
								plotID = plot;
							end
						end
					end
				else
					currentType = PRODUCTION_TYPE.BUILDING;
				end
			elseif(productionInfo.Type == "DISTRICT") then
				currentType = PRODUCTION_TYPE.PLACED;
			elseif(productionInfo.Type == "PROJECT") then
				currentType = PRODUCTION_TYPE.PROJECT;
			end

			if(currentType == 0) then
				print("Could not find production type for hash: " .. currentProductionHash);
			end

			prodQueue[cityID][1] = {
				entry=productionInfo,
				type=currentType,
				plotID=plotID
			}
		end

		Refresh();
	end
	--- =========================================================================================================
	--- =========================================================================================================
	--- =========================================================================================================



	--- =========================================================================================================
	--  ============================================= MODULE INITIALIZATION =====================================
	--- =========================================================================================================
	function Initialize()
		LoadQueues();
		Controls.PauseCollapseList:Stop();
		Controls.PauseDismissWindow:Stop();
		CreateCorrectTabs();
		Resize();
		SetDropOverlap( DROP_OVERLAP_REQUIRED );

		-- ===== Event listeners =====

		Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
		Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		Controls.PauseCollapseList:RegisterEndCallback( OnCollapseTheList );
		Controls.PauseDismissWindow:RegisterEndCallback( OnHide );
		Controls.QueueWindowToggle:RegisterCallback(Mouse.eLClick, ToggleQueueWindow);
		Controls.AlphaIn:RegisterEndCallback( OnPanelFadeInComplete )
		Controls.ProductionTabSelected:SetSpeed(100);
		Controls.QueueWindowReset:RegisterCallback(Mouse.eLClick, ResetSelectedCityQueue);

		ContextPtr:SetInitHandler( OnInit  );
		ContextPtr:SetInputHandler( OnInputHandler, true );
		ContextPtr:SetShutdown( OnShutdown );

		Events.CitySelectionChanged.Add( OnCitySelectionChanged );
		Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
		Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
		Events.LocalPlayerChanged.Add( OnLocalPlayerChanged );
		Events.PlayerTurnActivated.Add( OnPlayerTurnActivated );

		LuaEvents.CityBannerManager_ProductionToggle.Add( OnCityBannerManagerProductionToggle );
		LuaEvents.CityPanel_ChooseProduction.Add( OnCityPanelChooseProduction );
		LuaEvents.CityPanel_ChoosePurchase.Add( OnCityPanelChoosePurchase );
		LuaEvents.CityPanel_ProductionClose.Add( OnProductionClose );
		LuaEvents.CityPanel_ProductionOpen.Add( OnCityPanelProductionOpen );
		LuaEvents.CityPanel_PurchaseGoldOpen.Add( OnCityPanelPurchaseGoldOpen );
		LuaEvents.CityPanel_PurchaseFaithOpen.Add( OnCityPanelPurchaseFaithOpen );
		LuaEvents.CityPanel_ProductionOpenForQueue.Add( OnProductionOpenForQueue );
		LuaEvents.CityPanel_PurchasePlot.Add( OnCityPanelPurchasePlot );
		LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );
		LuaEvents.NotificationPanel_ChooseProduction.Add( OnNotificationPanelChooseProduction );
		LuaEvents.StrageticView_MapPlacement_ProductionOpen.Add( OnStrategicViewMapPlacementProductionOpen );
		LuaEvents.StrageticView_MapPlacement_ProductionClose.Add( OnStrategicViewMapPlacementProductionClose );
		LuaEvents.Tutorial_ProductionOpen.Add( OnTutorialProductionOpen );

		Events.CityProductionChanged.Add( OnCityProductionChanged );
		Events.CityProductionCompleted.Add(OnCityProductionCompleted);
		Events.CityProductionUpdated.Add(OnCityProductionUpdated);
		Events.CityMadePurchase.Add(Refresh);
	end
	Initialize();
end