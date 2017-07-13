package vshaxe;

class DisplayArguments {
    static inline var SELECT_PROVIDER_COMMAND = "haxe.selectDisplayArgumentsProvider";
    static inline var CURRENT_PROVIDER_MEMENTO_KEY = "haxe.displayArgumentsProviderName";
    static var statusBarWarningThemeColor = new ThemeColor("errorForeground");

    var context:ExtensionContext;
    var statusBarItem:StatusBarItem;
    var providers:Map<String, DisplayArgumentsProvider>;
    var currentProvider:Null<String>;
    var _onDidChangeArguments:EventEmitter<Array<String>>;

    public var arguments(default,null):Array<String>;

    public var onDidChangeArguments(get,never):Event<Array<String>>;
    inline function get_onDidChangeArguments() return _onDidChangeArguments.event;

    public function new(context) {
        this.context = context;
        providers = new Map();
        _onDidChangeArguments = new EventEmitter();
        context.subscriptions.push(_onDidChangeArguments);

        statusBarItem = window.createStatusBarItem(Left);
        statusBarItem.tooltip = "Select completion provider";
        statusBarItem.command = SELECT_PROVIDER_COMMAND;
        context.subscriptions.push(statusBarItem);

        context.subscriptions.push(commands.registerCommand(SELECT_PROVIDER_COMMAND, selectProvider));

        context.subscriptions.push(window.onDidChangeActiveTextEditor(_ -> updateStatusBarItem()));

        updateStatusBarItem();
    }

    public function registerProvider(name:String, provider:DisplayArgumentsProvider):Disposable {
        if (providers.exists(name)) {
            throw new js.Error('Display arguments provider `$name` is already registered.');
        }

        providers[name] = provider;

        if (getCurrentProviderName() == name)
            setCurrentProvider(name);
        else
            updateStatusBarItem();

        return new Disposable(function() {
            providers.remove(name);
            if (name == currentProvider)
                setCurrentProvider(null);
        });
    }

    function selectProvider() {
        var items = [for (name in providers.keys()) ({label: providers[name].label, description: "", name: name} : ProviderQuickPickItem)];

        if (items.length == 0) {
            window.showErrorMessage("No Haxe completion arguments providers registered.");
            return;
        }

        window.showQuickPick(items, {placeHolder: "Select Haxe completion arguments provider"}).then(item -> setCurrentProvider(if (item == null) null else item.name));
    }

    inline function getCurrentProviderName():Null<String> {
        return context.workspaceState.get(CURRENT_PROVIDER_MEMENTO_KEY);
    }

    function setCurrentProvider(name:Null<String>) {
        if (currentProvider != null) {
            var provider = providers[currentProvider];
            if (provider != null) provider.deactivate();
        }

        currentProvider = name;

        if (name != null) {
            var provider = providers[name];
            if (provider != null)
                provider.activate(provideArguments);
        }

        context.workspaceState.update(CURRENT_PROVIDER_MEMENTO_KEY, name);
        updateStatusBarItem();
    }

    function provideArguments(newArguments:Array<String>) {
        if (!newArguments.equals(arguments)) {
            arguments = newArguments;
            _onDidChangeArguments.fire(newArguments);
        }
    }

    function updateStatusBarItem() {
        if (window.activeTextEditor == null || languages.match({language: 'haxe', scheme: 'file'}, window.activeTextEditor.document) <= 0) {
            statusBarItem.hide();
            return;
        }

        if (providers.empty()) {
            statusBarItem.hide();
            return;
        }

        var label, color;
        if (currentProvider == null) {
            label = "select provider...";
            color = statusBarWarningThemeColor; // TODO: different color?
        } else {
            var provider = providers[currentProvider];
            if (provider == null) {
                label = '$currentProvider (not available)'; // selected but not (yet?) loaded
                color = statusBarWarningThemeColor;
            } else {
                label = provider.label;
                color = null;
            }
        }
        statusBarItem.color = color;
        statusBarItem.text = '$(gear) Haxe completion: $label';
        statusBarItem.show();
    }
}

private typedef ProviderQuickPickItem = {
    >QuickPickItem,
    var name:String;
}
