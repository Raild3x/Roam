--[[
	  ____   ___    _    __  __ 
	 |  _ \ / _ \  / \  |  \/  |
	 | |_) | | | |/ _ \ | |\/| |
	 |  _ <| |_| / ___ \| |  | |
	 |_| \_\\___/_/   \_\_|  |_|
 
 	V1.0
	Author: 		Raildex
	Date Created: 	02/17/2022
	Last Updated:	04/21/2022
	

	Welcome to R.O.A.M., Rail's Object Accesibility Manager.
	
		This Framework is intended to provide a structure for your objects and automatically 
	implement useful features such as inheritance, serialization, destruction, network communication,
	components, queries, tags, and more. This Framework was originally based of HawDevelopment's ECS module
	`River` and Sleitnik's Framework 'Knit' so shout out to them. I developed this framework in order to
	implement useful concepts from Entity Component Systems and allow users to have a base to build their
	custom Objects off of with built in useful features. It is built in such a way that it is able to be
	implemented with the standard Luau OOP formula and thus able to be merged with existing systems
	relatively easily. ROAM is also almost fully compatible with Luau's type checker and linter. ROAM
	provides access to unique ROAM types such as Entity, EntityClass, Query, Tag, Component, ComponentUnit,
	and Interface. It is highly recommended that you take advantage of these and build your classes to also
	work with the Luau linter.

		ROAM is meant to be used with proper code structure using individual Modules for each Object Class. 
	It is HIGHLY recommended that you use individual ModuleScripts for each Object, Query, and Component that
	you create and to place them in the proper ROAM sub folders. ROAM has 3 main subsections for user created
	Modules. A folder in ServerStorage for Server side modules, a folder in each player's PlayerScripts, and
	the Shared folder inside the main ROAM module. You should not touch anything in the Internal folder unless
	you are absolutely sure you know what you are doing, it is not recommended that users touch this as it
	could cause ROAM to break. You should never have to touch anything in there or require it directly as
	ROAM provides accessors to any Methods/Classes/Modules/Folders that you may need.

		To get started with ROAM you will need to make sure that all Folders are in the proper place. ROAM
	has a plugin that will do this for you (https://www.roblox.com/library/9366154643/ROAM). Do note that
	this Plugin is still under development. The plugin also provides a custom explorer for quick and
	efficient access to ROAM related folders and their descendants. The main module should be directly
	accesible from the ReplicatedStorage. Secondly you will need a control script to start ROAM, the plugin 
	will also eventually have this feature. It is HIGHLY recommended that ROAM is started as early as possible 
	on the Server and each Client in order for best results with the automatic Object network communication. 
	The code within these scripts should be the following:
	
	```
		--!nonstrict
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local ROAM = require(ReplicatedStorage.ROAM)
		local ROAM: ROAM.ROAM = ROAM	-- This line informs the linter of ROAM's API
		ROAM.Start():catch(warn):await()	-- This line starts ROAM
		
		-- In some other script you can use this line to wait for ROAM to be ready.
		ROAM.OnStart():await()
	```

		Once ROAM has been started on both Server and Client it is ready to be used. For more specific
	information on each of the classes you can check out their internals or read the API for them. There
	should be a script for each major type located below. I would reccomend starting out with Objects as
	they are the core features that the whole framework revolves around.
	
	Thanks for using ROAM! I hope it serves you well. If you have any questions, comments, concerns, or
	just want to tell me how much you hate my guts, feel free to DM me on ROBLOX.
	
	~Raildex;	Logan Hunt
























]]