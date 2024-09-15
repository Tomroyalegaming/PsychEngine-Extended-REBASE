package;

import WeekData;

import flixel.math.FlxPoint;
import flixel.ui.FlxButton;
import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import flash.geom.Rectangle;
import lime.utils.Assets;
import tjson.TJSON as Json;

import flixel.util.FlxSpriteUtil;
import AttachedSprite;
import options.ModSettingsSubState;
import flixel.addons.transition.FlxTransitionableState;

class ModsMenuState extends MusicBeatState
{
	var bg:FlxSprite;
	var icon:FlxSprite;
	var modName:Alphabet;
	var modDesc:FlxText;
	var modRestartText:FlxText;
	var modsList:ModsList = null;

	var bgList:FlxSprite;
	var buttonReload:MenuButton;
	//var buttonModFolder:MenuButton;
	var buttonEnableAll:MenuButton;
	var buttonDisableAll:MenuButton;
	var buttons:Array<MenuButton> = [];
	var settingsButton:MenuButton;

	var bgTitle:FlxSprite;
	var bgDescription:FlxSprite;
	var bgButtons:FlxSprite;

	var modsGroup:FlxTypedGroup<ModItem>;
	var curSelectedMod:Int = 0;
	
	var hoveringOnMods:Bool = true;
	var curSelectedButton:Int = 0; ///-1 = Enable/Disable All, -2 = Reload
	var modNameInitialY:Float = 0;

	var noModsSine:Float = 0;
	var noModsTxt:FlxText;

	var _lastControllerMode:Bool = false;
	var startMod:String = null;
	public function new(startMod:String = null)
	{
		this.startMod = startMod;
		super();
	}
	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		persistentUpdate = false;

		modsList = Paths.parseList();
		Paths.currentModDirectory = modsList.all[0] != null ? modsList.all[0] : '';

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF665AFF;
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);
		bg.screenCenter();

		bgList = FlxSpriteUtil.drawRoundRect(new FlxSprite(40, 40).makeGraphic(340, 440, FlxColor.TRANSPARENT), 0, 0, 340, 440, 15, 15, FlxColor.BLACK);
		bgList.alpha = 0.6;

		modsGroup = new FlxTypedGroup<ModItem>();

		for (i => mod in modsList.all)
		{
			if(startMod == mod) curSelectedMod = i;

			var modItem:ModItem = new ModItem(mod);
			if(modsList.disabled.contains(mod))
			{
				modItem.icon.color = 0xFFFF6666;
				modItem.text.color = FlxColor.GRAY;
			}
			modsGroup.add(modItem);
		}

		var mod:ModItem = modsGroup.members[curSelectedMod];
		if(mod != null) bg.color = mod.bgColor;

		//
		var buttonX = bgList.x;
		var buttonWidth = Std.int(bgList.width);
		var buttonHeight = 80;

		buttonReload = new MenuButton(buttonX, bgList.y + bgList.height + 20, buttonWidth, buttonHeight, "RELOAD", reload);
		add(buttonReload);
		
		var myY = buttonReload.y + buttonReload.bg.height + 20;
		/*buttonModFolder = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, "MODS FOLDER", function() {
			var modFolder = Paths.mods();
			if(!FileSystem.exists(modFolder))
			{
				trace('created missing folder');
				FileSystem.createDirectory(modFolder);
			}
			CoolUtil.openFolder(modFolder);
		});
		add(buttonModFolder);*/

		buttonEnableAll = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, "ENABLE ALL", function() {
			buttonEnableAll.ignoreCheck = false;
			for (mod in modsGroup.members)
			{
				if(modsList.disabled.contains(mod.folder))
				{
					modsList.disabled.remove(mod.folder);
					modsList.enabled.push(mod.folder);
					mod.icon.color = FlxColor.WHITE;
					mod.text.color = FlxColor.WHITE;
				}
			}
			updateModDisplayData();
			checkToggleButtons();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonEnableAll.bg.color = FlxColor.GREEN;
		buttonEnableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonEnableAll.bg.color = FlxColor.GREEN;
		add(buttonEnableAll);

		buttonDisableAll = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, "DISABLE ALL", function() {
			buttonDisableAll.ignoreCheck = false;
			for (mod in modsGroup.members)
			{
				if(modsList.enabled.contains(mod.folder))
				{
					modsList.enabled.remove(mod.folder);
					modsList.disabled.push(mod.folder);
					mod.icon.color = 0xFFFF6666;
					mod.text.color = FlxColor.GRAY;
				}
			}
			updateModDisplayData();
			checkToggleButtons();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		});
		buttonDisableAll.bg.color = 0xFFFF6666;
		buttonDisableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonDisableAll.bg.color = 0xFFFF6666;
		add(buttonDisableAll);
		checkToggleButtons();

		if(modsList.all.length < 1)
		{
			buttonDisableAll.visible = buttonDisableAll.enabled = false;
			buttonEnableAll.visible = true;

			var myX = bgList.x + bgList.width + 20;
			noModsTxt = new FlxText(myX, 0, FlxG.width - myX - 20, "NO MODS INSTALLED\nPRESS BACK TO EXIT OR INSTALL A MOD", 48);
			if(FlxG.random.bool(0.1)) noModsTxt.text += '\nBITCH.'; //meanie
			noModsTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			noModsTxt.borderSize = 2;
			add(noModsTxt);
			noModsTxt.screenCenter(Y);

			var txt = new FlxText(bgList.x + 15, bgList.y + 15, bgList.width - 30, "No Mods found.", 16);
			txt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE);
			add(txt);

			FlxG.autoPause = false;
			changeSelectedMod();
			return super.create();
		}
		//

		bgTitle = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgList.x + bgList.width + 20, 40).makeGraphic(840, 180, FlxColor.TRANSPARENT), 0, 0, 840, 180, 15, 15, 0, 0, FlxColor.BLACK);
		bgTitle.alpha = 0.6;
		add(bgTitle);

		icon = new FlxSprite(bgTitle.x + 15, bgTitle.y + 15);
		add(icon);

		modNameInitialY = icon.y + 80;
		modName = new Alphabet(icon.x + 165, modNameInitialY, "", true);
		modName.scaleY = 0.8;
		add(modName);

		bgDescription = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgTitle.x, bgTitle.y + 200).makeGraphic(840, 450, FlxColor.TRANSPARENT), 0, 0, 840, 450, 0, 0, 15, 15, FlxColor.BLACK);
		bgDescription.alpha = 0.6;
		add(bgDescription);
		
		modDesc = new FlxText(bgDescription.x + 15, bgDescription.y + 15, bgDescription.width - 30, "", 24);
		modDesc.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT);
		add(modDesc);

		var myHeight = 100;
		modRestartText = new FlxText(bgDescription.x + 15, bgDescription.y + bgDescription.height - myHeight - 25, bgDescription.width - 30, "* Moving or Toggling On/Off this Mod will restart the game.", 16);
		modRestartText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT);
		add(modRestartText);

		bgButtons = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgDescription.x, bgDescription.y + bgDescription.height - myHeight).makeGraphic(840, myHeight, FlxColor.TRANSPARENT), 0, 0, 840, myHeight, 0, 0, 15, 15, FlxColor.WHITE);
		bgButtons.color = FlxColor.BLACK;
		bgButtons.alpha = 0.2;
		add(bgButtons);

		var buttonsX = bgButtons.x + 320;
		var buttonsY = bgButtons.y + 10;

		var button = new MenuButton(buttonsX, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(0), 54, 54); //Move to the top
		button.icon.animation.add('icon', [0]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);

		var button = new MenuButton(buttonsX + 100, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod - 1), 54, 54); //Move up
		button.icon.animation.add('icon', [1]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);

		var button = new MenuButton(buttonsX + 200, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod + 1), 54, 54); //Move down
		button.icon.animation.add('icon', [2]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		
		if(modsList.all.length < 2)
		{
			for (button in buttons)
				button.enabled = false;
		}

		settingsButton = new MenuButton(buttonsX + 300, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() //Settings
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null && curMod.settings != null && curMod.settings.length > 0)
			{
				openSubState(new ModSettingsSubState(curMod.settings, curMod.folder, curMod.name));
			}
		}, 54, 54);

		settingsButton.icon.animation.add('icon', [3]);
		settingsButton.icon.animation.play('icon', true);
		add(settingsButton);
		buttons.push(settingsButton);

		if(modsGroup.members[curSelectedMod].settings == null || modsGroup.members[curSelectedMod].settings.length < 1)
			settingsButton.enabled = false;

		var button = new MenuButton(buttonsX + 400, buttonsY, 80, 80, Paths.image('modsMenuButtons'), function() //On/Off
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			var mod:String = curMod.folder;
			if(!modsList.disabled.contains(mod)) //Enable
			{
				modsList.enabled.remove(mod);
				modsList.disabled.push(mod);
			}
			else //Disable
			{
				modsList.disabled.remove(mod);
				modsList.enabled.push(mod);
			}
			curMod.icon.color = modsList.disabled.contains(mod) ? 0xFFFF6666 : FlxColor.WHITE;
			curMod.text.color = modsList.disabled.contains(mod) ? FlxColor.GRAY : FlxColor.WHITE;

			if(curMod.mustRestart) waitingToRestart = true;
			updateModDisplayData();
			checkToggleButtons();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		}, 54, 54);
		button.icon.animation.add('icon', [4]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		button.focusChangeCallback = function(focus:Bool) {
			if(!focus)
				button.bg.color = modsList.enabled.contains(modsGroup.members[curSelectedMod].folder) ? FlxColor.GREEN : 0xFFFF6666;
		};

		if(modsList.all.length < 1)
		{
			for (btn in buttons) btn.enabled = false;
			button.focusChangeCallback = null;
		}
		
		add(bgList);
		add(modsGroup);
		_lastControllerMode = controls.controllerMode;

		changeSelectedMod();
		super.create();
	}
	
	var nextAttempt:Float = 1;
	var holdingMod:Bool = false;
	var mouseOffsets:FlxPoint = new FlxPoint();
	var holdingElapsed:Float = 0;
	var gottaClickAgain:Bool = false;

	var holdTime:Float = 0;

	override function update(elapsed:Float)
	{
		if(controls.BACK && hoveringOnMods)
		{
			if(colorTween != null) {
				colorTween.cancel();
			}
			saveTxt();

			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(waitingToRestart)
			{
				//MusicBeatState.switchState(new TitleState());
				TitleState.initialized = false;
				TitleState.closedState = false;
				FlxG.sound.music.fadeOut(0.3);
				if(FreeplayState.vocals != null)
				{
					FreeplayState.vocals.fadeOut(0.3);
					FreeplayState.vocals = null;
				}
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			}
			else MusicBeatState.switchState(new MainMenuState());

			persistentUpdate = false;
			FlxG.mouse.visible = false;
			return;
		}

		if(Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10)
		{
			controls.controllerMode = false;
			if(!FlxG.mouse.visible) FlxG.mouse.visible = true;
		}
		
		if(controls.controllerMode != _lastControllerMode)
		{
			if(controls.controllerMode) FlxG.mouse.visible = false;
			_lastControllerMode = controls.controllerMode;
		}

		if(controls.UI_DOWN_R || controls.UI_UP_R) holdTime = 0;

		if(modsList.all.length > 0)
		{
			if(controls.controllerMode && holdingMod)
			{
				holdingMod = false;
				holdingElapsed = 0;
				updateItemPositions();
			}

			var lastMode = hoveringOnMods;
			if(modsList.all.length > 1)
			{
				if(FlxG.mouse.justPressed)
				{
					for (i in centerMod-2...centerMod+3)
					{
						var mod = modsGroup.members[i];
						if(mod != null && mod.visible && FlxG.mouse.overlaps(mod))
						{
							hoveringOnMods = true;
							var button = getButton();
							button.ignoreCheck = button.onFocus = false;
							mouseOffsets.x = FlxG.mouse.x - mod.x;
							mouseOffsets.y = FlxG.mouse.y - mod.y;
							curSelectedMod = i;
							changeSelectedMod();
							break;
						}
					}
					hoveringOnMods = true;
					var button = getButton();
					button.ignoreCheck = button.onFocus = false;
					gottaClickAgain = false;
				}

				if(hoveringOnMods)
				{
					var shiftMult:Int = (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) || FlxG.gamepads.anyPressed(RIGHT_SHOULDER)) ? 4 : 1;
					if(controls.UI_DOWN_P)
						changeSelectedMod(shiftMult);
					else if(controls.UI_UP_P)
						changeSelectedMod(-shiftMult);
					else if(FlxG.mouse.wheel != 0 && curSelectedMod != 0 && curSelectedMod != modsList.all.length - 1)
						changeSelectedMod(-FlxG.mouse.wheel * shiftMult);
					else if(FlxG.keys.justPressed.HOME || FlxG.keys.justPressed.END ||
						FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					{
						if(FlxG.keys.justPressed.END || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)) curSelectedMod = modsList.all.length-1;
						else curSelectedMod = 0;
						changeSelectedMod();
					}
					else if(controls.UI_UP || controls.UI_DOWN)
					{
						var lastHoldTime:Float = holdTime;
						holdTime += elapsed;
						if(holdTime > 0.5 && Math.floor(lastHoldTime * 8) != Math.floor(holdTime * 8)) changeSelectedMod(shiftMult * (controls.UI_UP ? -1 : 1));
					}
					else if(FlxG.mouse.pressed && !gottaClickAgain)
					{
						var curMod:ModItem = modsGroup.members[curSelectedMod];
						if(curMod != null)
						{
							if(!holdingMod && FlxG.mouse.justMoved && FlxG.mouse.overlaps(curMod)) holdingMod = true;

							if(holdingMod)
							{
								var moved:Bool = false;
								for (i in centerMod-2...centerMod+3)
								{
									var mod = modsGroup.members[i];
									if(mod != null && mod.visible && FlxG.mouse.overlaps(mod) && curSelectedMod != i)
									{
										moveModToPosition(i);
										moved = true;
										break;
									}
								}
								
								if(!moved)
								{
									var factor:Float = -1;
									if(FlxG.mouse.y < bgList.y)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (bgList.y - FlxG.mouse.y) / 100)));
									else if(FlxG.mouse.y > bgList.y + bgList.height)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (FlxG.mouse.y - bgList.y - bgList.height) / 100)));
		
									if(factor >= 0)
									{
										holdingElapsed += elapsed;
										if(holdingElapsed >= factor)
										{
											holdingElapsed = 0;
											var newPos = curSelectedMod;
											if(FlxG.mouse.y < bgList.y) newPos--;
											else newPos++;
											moveModToPosition(Std.int(Math.max(0, Math.min(modsGroup.length - 1, newPos))));
										}
									}
								}
								curMod.x = FlxG.mouse.x - mouseOffsets.x;
								curMod.y = FlxG.mouse.y - mouseOffsets.y;
							}
						}
						
					}
					else if(FlxG.mouse.justReleased && holdingMod)
					{
						holdingMod = false;
						holdingElapsed = 0;
						updateItemPositions();
					}
				}
			}

			if(lastMode == hoveringOnMods)
			{
				if(hoveringOnMods)
				{
					if(controls.UI_RIGHT_P)
					{
						hoveringOnMods = false;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						curSelectedButton = 0;
						changeSelectedButton();
					}
				}
				else 
				{
					if(controls.BACK)
					{
						hoveringOnMods = true;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						changeSelectedMod();
					}
					else if(controls.ACCEPT)
					{
						var button = getButton();
						if(button.onClick != null) button.onClick();
					}
					else if(curSelectedButton < 0)
					{
						if(controls.UI_UP_P)
						{
							switch(curSelectedButton)
							{
								case -2:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
								case -1:
									changeSelectedButton(-1);
							}
						}
						else if(controls.UI_DOWN_P)
						{
							switch(curSelectedButton)
							{
								case -2:
									changeSelectedButton(1);
								case -1:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
							}
						}
						else if(controls.UI_RIGHT_P)
						{
							var button = getButton();
							button.ignoreCheck = button.onFocus = false;
							curSelectedButton = 0;
							changeSelectedButton();
						}
					}
					else if(controls.UI_LEFT_P)
						changeSelectedButton(-1);
					else if(controls.UI_RIGHT_P)
						changeSelectedButton(1);
				}
			}
		}
		else
		{
			noModsSine += 180 * elapsed;
			noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);
			
			// Keep refreshing mods list every 2 seconds until you add a mod on the folder
			nextAttempt -= elapsed;
			if(nextAttempt < 0)
			{
				nextAttempt = 1;
				@:privateAccess
				Paths.updateModList();
				modsList = Paths.parseList();
				if(modsList.all.length > 0)
				{
					trace('mod(s) found! reloading');
					reload();
				}
			}
		}
		super.update(elapsed);
	}

	function changeSelectedButton(add:Int = 0)
	{
		var max = buttons.length - 1;
		
		var button = getButton();
		button.ignoreCheck = button.onFocus = false;

		curSelectedButton += add;
		if(curSelectedButton < -2)
			curSelectedButton = -2;
		else if(curSelectedButton > max)
			curSelectedButton = max;

		var button = getButton();
		button.ignoreCheck = button.onFocus = true;

		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod != null) curMod.selectBg.visible = false;
		if(curSelectedButton < 0)
		{
			bgButtons.color = FlxColor.BLACK;
			bgButtons.alpha = 0.2;
		}
		else
		{
			bgButtons.color = FlxColor.WHITE;
			bgButtons.alpha = 0.8;
		}

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function getButton()
	{
		switch(curSelectedButton)
		{
			case -2: return buttonReload;
			case -1: return buttonEnableAll.enabled ? buttonEnableAll : buttonDisableAll;
		}

		if(modsList.all.length < 1) return buttonReload; //prevent possible crash from my irresponsibility
		return buttons[Std.int(Math.max(0, Math.min(buttons.length-1, curSelectedButton)))];
	}

	function changeSelectedMod(add:Int = 0)
	{
		var max = modsList.all.length - 1;
		if(max < 0) return;

		if(hoveringOnMods)
		{
			var button = getButton();
			button.ignoreCheck = button.onFocus = false;
		}

		var lastSelected = curSelectedMod;
		curSelectedMod += add;

		var limited:Bool = false;
		if(curSelectedMod < 0)
		{
			curSelectedMod = 0;
			limited = true;
		}
		else if(curSelectedMod > max)
		{
			curSelectedMod = max;
			limited = true;
		}
		
		if(limited && Math.abs(add) == 1)
		{
			if(add < 0) // pressed up on first mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -1;
				changeSelectedButton();
				return;
			}
			else // pressed down on last mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -2;
				changeSelectedButton();
				return;
			}
		}
		
		holdingMod = false;
		holdingElapsed = 0;
		gottaClickAgain = true;
		updateModDisplayData();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		
		if(hoveringOnMods)
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null) curMod.selectBg.visible = true;
			bgButtons.color = FlxColor.BLACK;
			bgButtons.alpha = 0.2;
		}
	}

	var colorTween:FlxTween = null;
	function updateModDisplayData()
	{
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod == null) return;

		if(colorTween != null)
		{
			colorTween.cancel();
			colorTween.destroy();
		}
		colorTween = FlxTween.color(bg, 1, bg.color, curMod.bgColor, {onComplete: function(twn:FlxTween) colorTween = null});

		if(Math.abs(centerMod - curSelectedMod) > 2)
		{
			if(centerMod < curSelectedMod)
				centerMod = curSelectedMod - 2;
			else centerMod = curSelectedMod + 2;
		}
		updateItemPositions();

		icon.loadGraphic(curMod.icon.graphic, true, 150, 150);
		icon.antialiasing 