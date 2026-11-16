Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$cookbookRoot = Join-Path $workspaceRoot 'cookbook'

function Pick-Value {
    param(
        [string[]]$Values,
        [int]$Index
    )

    if (-not $Values -or $Values.Count -eq 0) {
        return ''
    }

    return $Values[$Index % $Values.Count]
}

function Resolve-Template {
    param(
        [string]$Value,
        [hashtable]$Country,
        [int]$Index
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $resolved = $Value
    $tokens = [ordered]@{
        '{place}' = (Pick-Value $Country.Places $Index)
        '{place2}' = (Pick-Value $Country.Places ($Index + 2))
        '{cheese}' = $Country.Cheese
        '{herb}' = (Pick-Value $Country.Herbs $Index)
        '{protein}' = (Pick-Value $Country.Proteins $Index)
        '{protein2}' = (Pick-Value $Country.Proteins ($Index + 1))
        '{vegetable}' = (Pick-Value $Country.Vegetables $Index)
        '{vegetable2}' = (Pick-Value $Country.Vegetables ($Index + 1))
        '{green}' = (Pick-Value $Country.Greens $Index)
        '{fish}' = (Pick-Value $Country.Fish $Index)
        '{fruit}' = (Pick-Value $Country.Fruits $Index)
        '{fruit2}' = (Pick-Value $Country.Fruits ($Index + 1))
        '{nut}' = (Pick-Value $Country.Nuts $Index)
        '{fat}' = $Country.Fat
        '{acid}' = $Country.Acid
        '{signature}' = $Country.Signature
    }

    foreach ($token in $tokens.Keys) {
        $resolved = $resolved.Replace($token, [string]$tokens[$token])
    }

    return $resolved
}

function Convert-RecipeString {
    param(
        [string]$Line,
        [hashtable]$Country,
        [int]$Index
    )

    $parts = $Line -split '\|'
    if ($parts.Count -ne 6) {
        throw "Invalid recipe definition: $Line"
    }

    $resolvedTitle = Resolve-Template $parts[0] $Country $Index
    if ($parts[0].Contains('{')) {
        $resolvedTitle = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($resolvedTitle.ToLowerInvariant())
    }

    return [ordered]@{
        Title = $resolvedTitle
        Type = Resolve-Template $parts[1] $Country $Index
        Main = Resolve-Template $parts[2] $Country $Index
        Secondary = Resolve-Template $parts[3] $Country $Index
        Flavor = Resolve-Template $parts[4] $Country $Index
        Category = Resolve-Template $parts[5] $Country $Index
    }
}

function New-Slug {
    param([string]$Text)

    $slug = $Text.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    return $slug
}

function Get-Measure {
    param(
        [string]$Item,
        [string]$Default = '200 g'
    )

    $text = $Item.ToLowerInvariant()

    switch -Regex ($text) {
        'garlic' { return '3 cloves' }
        'onion' { return '1 large' }
        'rice|bulgur|barley' { return '180 g' }
        'beans|lentils|chickpeas' { return '300 g cooked or 180 g dried' }
        'vine leaves|cabbage leaves' { return '16 leaves' }
        'sweet peppers|peppers' { return '6 medium' }
        'tomatoes and peppers' { return '8 medium mixed vegetables' }
        'tomatoes' { return '400 g' }
        'cucumber' { return '1 large' }
        'potatoes' { return '400 g' }
        'chard|spinach|leek|cabbage|okra|zucchini|eggplant|pumpkin|sauerkraut|collard greens|greens|mushrooms|pearl onions' { return '300 g' }
        'trout|sea bass|sardines|mixed fish|river fish|grilled fish|fish|squid' { return '600 g' }
        'beef|mince|lamb|veal|pork|chicken|smoked meat|offal|tripe|sausage' { return '500 g' }
        'yogurt|kajmak|sour cream|cream|milk' { return '250 g or ml' }
        'walnuts|almond|nuts|pine nuts|raisins|poppy seeds|jam|prunes' { return '80 g' }
        'phyllo dough' { return '8 sheets' }
        'bread dough|dough' { return '500 g' }
        'flour batter' { return '500 ml' }
        'flour|cornmeal|buckwheat flour|semolina' { return '250 g' }
        'eggs' { return '4 large' }
        'bread|flatbread' { return '4 pieces' }
        'apple|cherry|fig|quince|apples|berries' { return '300 g' }
        default { return $Default }
    }
}

function Add-CustomIngredient {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Item,
        [string]$Default = '200 g'
    )

    if ([string]::IsNullOrWhiteSpace($Item)) {
        return
    }

    $List.Add("$(Get-Measure $Item $Default) $Item")
}

function Get-StuffedBaseLine {
    param([string]$Item)

    $text = $Item.ToLowerInvariant()
    switch -Regex ($text) {
        'vine leaves|cabbage leaves' { return "16 prepared $Item" }
        'tomatoes and peppers' { return '8 medium mixed tomatoes and peppers' }
        'peppers|eggplant|tomatoes' { return "8 medium $Item" }
        default { return "8 prepared portions of $Item" }
    }
}

function Get-RecipeMeta {
    param([string]$Type)

    switch ($Type) {
        'Pie' { return @{ Time = '1 hour'; Yield = '6 servings' } }
        'Soup' { return @{ Time = '55 minutes'; Yield = '6 servings' } }
        'ChilledSoup' { return @{ Time = '20 minutes plus chilling'; Yield = '4 servings' } }
        'Stew' { return @{ Time = '1 hour 15 minutes'; Yield = '6 servings' } }
        'Bake' { return @{ Time = '1 hour 10 minutes'; Yield = '6 servings' } }
        'Stuffed' { return @{ Time = '1 hour 20 minutes'; Yield = '6 servings' } }
        'Grill' { return @{ Time = '45 minutes'; Yield = '4 to 6 servings' } }
        'Salad' { return @{ Time = '20 minutes'; Yield = '4 servings' } }
        'Relish' { return @{ Time = '1 hour'; Yield = '3 cups' } }
        'Dip' { return @{ Time = '15 minutes'; Yield = '4 servings' } }
        'Cake' { return @{ Time = '1 hour'; Yield = '8 slices' } }
        'Cookie' { return @{ Time = '45 minutes'; Yield = '24 pieces' } }
        'Bread' { return @{ Time = '1 hour 30 minutes'; Yield = '1 loaf or tray' } }
        'FriedDough' { return @{ Time = '45 minutes'; Yield = '16 to 20 pieces' } }
        'Pudding' { return @{ Time = '40 minutes'; Yield = '6 servings' } }
        'Porridge' { return @{ Time = '35 minutes'; Yield = '4 servings' } }
        'Skillet' { return @{ Time = '35 minutes'; Yield = '4 servings' } }
        'SweetBread' { return @{ Time = '2 hours 30 minutes'; Yield = '1 loaf' } }
        'Sandwich' { return @{ Time = '35 minutes'; Yield = '4 sandwiches' } }
        'LayeredPastry' { return @{ Time = '1 hour 20 minutes'; Yield = '10 pieces' } }
        'FilledDough' { return @{ Time = '1 hour 10 minutes'; Yield = '6 servings' } }
        'RolledPastry' { return @{ Time = '2 hours'; Yield = '8 to 10 slices' } }
        default { return @{ Time = '1 hour'; Yield = '4 to 6 servings' } }
    }
}

function Get-Ingredients {
    param(
        [hashtable]$Country,
        [hashtable]$Recipe
    )

    $lines = [System.Collections.Generic.List[string]]::new()

    switch ($Recipe.Type) {
        'Pie' {
            $lines.Add('8 sheets phyllo or 500 g thin pie dough')
            $lines.Add("3 tbsp $($Country.Fat)")
            $lines.Add('1 large onion, finely chopped')
            Add-CustomIngredient $lines $Recipe.Main '300 g'
            Add-CustomIngredient $lines $Recipe.Secondary '180 g'
            $lines.Add('2 eggs')
            $lines.Add('200 g yogurt')
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'Soup' {
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add('1 large onion, chopped')
            $lines.Add('2 garlic cloves, minced')
            Add-CustomIngredient $lines $Recipe.Main '300 g'
            Add-CustomIngredient $lines $Recipe.Secondary '160 g'
            $lines.Add('1.2 liters stock or water')
            $lines.Add('1 tsp paprika')
            $lines.Add("1 tbsp chopped seasoning mix of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'ChilledSoup' {
            $lines.Add('600 g yogurt')
            $lines.Add('250 ml cold water')
            Add-CustomIngredient $lines $Recipe.Main '250 g'
            Add-CustomIngredient $lines $Recipe.Secondary '80 g'
            $lines.Add("1 tbsp seasoning mix of $($Recipe.Flavor)")
            $lines.Add("1 tbsp $($Country.Fat)")
            $lines.Add('salt')
        }
        'Stew' {
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add('1 large onion, sliced')
            Add-CustomIngredient $lines $Recipe.Main '500 g'
            Add-CustomIngredient $lines $Recipe.Secondary '200 g'
            $lines.Add('2 tomatoes, chopped')
            $lines.Add('700 ml stock or water')
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'Bake' {
            $lines.Add("2 tbsp $($Country.Fat)")
            Add-CustomIngredient $lines $Recipe.Main '600 g'
            Add-CustomIngredient $lines $Recipe.Secondary '200 g'
            $lines.Add('1 large onion, sliced')
            $lines.Add('250 g tomato or yogurt sauce')
            $lines.Add('250 ml stock or water')
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'Stuffed' {
            $lines.Add((Get-StuffedBaseLine $Recipe.Main))
            Add-CustomIngredient $lines $Recipe.Secondary '180 g'
            $lines.Add('250 g minced meat or chopped mushrooms')
            $lines.Add('1 large onion, finely chopped')
            $lines.Add('2 tomatoes, grated')
            $lines.Add('500 ml stock or water')
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add('salt and black pepper')
        }
        'Grill' {
            Add-CustomIngredient $lines $Recipe.Main '600 g'
            Add-CustomIngredient $lines $Recipe.Secondary '120 g'
            $lines.Add('2 garlic cloves, minced')
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
            $lines.Add('flatbread or raw onion for serving')
        }
        'Salad' {
            Add-CustomIngredient $lines $Recipe.Main '350 g'
            Add-CustomIngredient $lines $Recipe.Secondary '200 g'
            $lines.Add('1 small onion or handful of olives')
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add("1 tbsp $($Country.Acid) juice or vinegar")
            $lines.Add("1 tbsp chopped seasoning mix of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'Relish' {
            Add-CustomIngredient $lines $Recipe.Main '600 g'
            Add-CustomIngredient $lines $Recipe.Secondary '250 g'
            $lines.Add('1 large onion')
            $lines.Add('2 garlic cloves')
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add("1 tbsp $($Country.Acid) juice or vinegar")
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'Dip' {
            Add-CustomIngredient $lines $Recipe.Main '300 g'
            Add-CustomIngredient $lines $Recipe.Secondary '150 g'
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add("1 tbsp $($Country.Acid) juice or vinegar")
            $lines.Add('2 to 4 tbsp yogurt or water as needed')
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'Cake' {
            $lines.Add('220 g flour or semolina')
            $lines.Add('120 g sugar')
            $lines.Add('3 eggs')
            $lines.Add('120 ml neutral liquid')
            Add-CustomIngredient $lines $Recipe.Main '160 g'
            Add-CustomIngredient $lines $Recipe.Secondary '120 g'
            $lines.Add('80 g melted butter or oil')
            $lines.Add("1 tbsp $($Recipe.Flavor)")
            $lines.Add('1 tsp baking powder')
        }
        'Cookie' {
            $lines.Add('280 g flour')
            $lines.Add('120 g butter')
            $lines.Add('100 g sugar')
            Add-CustomIngredient $lines $Recipe.Main '120 g'
            Add-CustomIngredient $lines $Recipe.Secondary '80 g'
            $lines.Add('1 egg')
            $lines.Add("1 tsp $($Recipe.Flavor)")
            $lines.Add('pinch of salt')
        }
        'Bread' {
            $lines.Add('400 g flour or cornmeal')
            $lines.Add('1 tsp salt')
            $lines.Add('1 tsp yeast or baking powder')
            $lines.Add('250 ml warm liquid')
            Add-CustomIngredient $lines $Recipe.Main '180 g'
            Add-CustomIngredient $lines $Recipe.Secondary '120 g'
            $lines.Add('2 tbsp butter or oil')
            $lines.Add("1 tsp $($Recipe.Flavor)")
        }
        'FriedDough' {
            $lines.Add('350 g flour')
            $lines.Add('1 tsp yeast or baking powder')
            $lines.Add('200 ml warm liquid')
            Add-CustomIngredient $lines $Recipe.Main '150 g'
            Add-CustomIngredient $lines $Recipe.Secondary '100 g'
            $lines.Add('oil for frying')
            $lines.Add("1 tsp $($Recipe.Flavor)")
            $lines.Add('pinch of salt')
        }
        'Pudding' {
            $lines.Add('700 ml liquid')
            Add-CustomIngredient $lines $Recipe.Main '180 g'
            Add-CustomIngredient $lines $Recipe.Secondary '100 g'
            $lines.Add('80 g sugar')
            $lines.Add('1 tbsp butter')
            $lines.Add("1 tbsp $($Recipe.Flavor)")
        }
        'Porridge' {
            $lines.Add('220 g cornmeal, flour, or cooked beans')
            $lines.Add('700 ml water or milk')
            Add-CustomIngredient $lines $Recipe.Main '180 g'
            Add-CustomIngredient $lines $Recipe.Secondary '120 g'
            $lines.Add('2 tbsp butter')
            $lines.Add("1 tbsp $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'Skillet' {
            $lines.Add("2 tbsp $($Country.Fat)")
            Add-CustomIngredient $lines $Recipe.Main '300 g'
            Add-CustomIngredient $lines $Recipe.Secondary '160 g'
            $lines.Add('1 large onion, sliced')
            $lines.Add('2 tomatoes, chopped')
            $lines.Add("1 tbsp seasoning blend of $($Recipe.Flavor)")
            $lines.Add('salt and black pepper')
        }
        'SweetBread' {
            $lines.Add('450 g flour')
            $lines.Add('7 g yeast')
            $lines.Add('120 ml warm liquid')
            $lines.Add('80 g sugar')
            $lines.Add('2 eggs')
            $lines.Add('80 g butter')
            Add-CustomIngredient $lines $Recipe.Main '120 g'
            Add-CustomIngredient $lines $Recipe.Secondary '100 g'
            $lines.Add("1 tbsp $($Recipe.Flavor)")
        }
        'Sandwich' {
            Add-CustomIngredient $lines $Recipe.Main '500 g'
            Add-CustomIngredient $lines $Recipe.Secondary '150 g'
            $lines.Add('4 bread rolls or half loaves')
            $lines.Add('1 lemon, cut in wedges')
            $lines.Add('handful of fresh greens')
            $lines.Add("2 tbsp $($Country.Fat)")
            $lines.Add("1 tbsp $($Recipe.Flavor)")
        }
        'LayeredPastry' {
            $lines.Add('8 sheets phyllo dough')
            $lines.Add('80 g melted butter')
            Add-CustomIngredient $lines $Recipe.Main '180 g'
            Add-CustomIngredient $lines $Recipe.Secondary '120 g'
            $lines.Add('120 ml syrup or honey')
            $lines.Add("1 tbsp $($Recipe.Flavor)")
        }
        'FilledDough' {
            $lines.Add('300 g flour')
            $lines.Add('1 egg')
            $lines.Add('120 ml water')
            Add-CustomIngredient $lines $Recipe.Main '180 g'
            Add-CustomIngredient $lines $Recipe.Secondary '120 g'
            $lines.Add('2 tbsp melted butter or yogurt sauce')
            $lines.Add("1 tbsp $($Recipe.Flavor)")
            $lines.Add('pinch of salt')
        }
        'RolledPastry' {
            $lines.Add('350 g flour')
            $lines.Add('7 g yeast')
            $lines.Add('150 ml warm milk or water')
            $lines.Add('60 g butter')
            Add-CustomIngredient $lines $Recipe.Main '180 g'
            Add-CustomIngredient $lines $Recipe.Secondary '120 g'
            $lines.Add('1 egg for brushing')
            $lines.Add("1 tbsp $($Recipe.Flavor)")
        }
        default {
            Add-CustomIngredient $lines $Recipe.Main '300 g'
            Add-CustomIngredient $lines $Recipe.Secondary '150 g'
            $lines.Add("1 tbsp $($Recipe.Flavor)")
        }
    }

    return $lines.ToArray()
}

function Get-Method {
    param(
        [hashtable]$Country,
        [hashtable]$Recipe
    )

    switch ($Recipe.Type) {
        'Pie' {
            return @(
                'Heat the oven to 200 C and oil a baking tray.',
                "Cook the onion with the $($Recipe.Main) until softened, then fold in the $($Recipe.Secondary) and the $($Recipe.Flavor).",
                'Whisk the eggs and yogurt with a pinch of salt to make a loose binding mixture.',
                'Layer the dough with oil, spoon the filling between layers, and finish with the yogurt mixture over the top.',
                'Bake until bronzed and crisp, then rest for 10 minutes before cutting.'
            )
        }
        'Soup' {
            return @(
                'Warm the fat in a pot and cook the onion and garlic until fragrant.',
                "Add the $($Recipe.Main), the $($Recipe.Secondary), and paprika, and stir for 2 minutes.",
                'Pour in the stock and simmer gently until the main ingredient is tender.',
                'Taste, crush a little of the soup to thicken it if desired, and add the seasoning blend.',
                "Serve hot with bread and a final spoon of $($Country.Fat)."
            )
        }
        'ChilledSoup' {
            return @(
                'Whisk the yogurt and cold water until smooth and lightly frothy.',
                "Stir in the $($Recipe.Main), the $($Recipe.Secondary), and the $($Recipe.Flavor).",
                'Season carefully with salt and a drizzle of oil.',
                'Chill for at least 20 minutes so the flavors settle.',
                'Serve very cold.'
            )
        }
        'Stew' {
            return @(
                'Brown the onion in fat until golden.',
                "Add the $($Recipe.Main) and cook until it picks up some color.",
                "Stir in the $($Recipe.Secondary), tomatoes, and $($Recipe.Flavor).",
                'Add the stock, cover, and simmer slowly until rich and tender.',
                "Adjust salt, reduce the sauce if needed, and serve with bread or a spoon of yogurt."
            )
        }
        'Bake' {
            return @(
                'Heat the oven to 190 C.',
                "Brown the $($Recipe.Main) lightly with the onion, then add the $($Recipe.Secondary) and the seasoning blend.",
                'Transfer everything to a baking dish, moisten with sauce and stock, and cover loosely.',
                'Bake until the tray is bubbling and the top starts to bronze, uncovering near the end.',
                'Rest for 10 minutes before serving.'
            )
        }
        'Stuffed' {
            return @(
                'Prepare the vegetables or leaves so they are ready to fill.',
                "Cook the onion with the rice and mix in the minced meat or mushrooms, then season with $($Recipe.Flavor).",
                "Fill the $($Recipe.Main) loosely and arrange them snugly in a pot or tray.",
                'Add grated tomato, stock, and oil, then cover and cook until the filling is tender.',
                'Rest briefly before serving so the parcels hold together.'
            )
        }
        'Grill' {
            return @(
                "Combine the $($Recipe.Main), the $($Recipe.Secondary), garlic, and the seasoning blend.",
                'Mix well and let the mixture rest for 15 minutes.',
                'Shape into skewers, patties, or small logs depending on the dish.',
                'Grill or sear over high heat until browned outside and juicy inside.',
                'Serve immediately with flatbread, onion, and something cool on the side.'
            )
        }
        'Salad' {
            return @(
                "Cut the $($Recipe.Main) and the $($Recipe.Secondary) into bite-size pieces.",
                'Add onion or olives if using.',
                "Dress with $($Country.Fat), $($Country.Acid), and the seasoning mix.",
                'Toss gently so the vegetables stay fresh and crisp.',
                'Serve right away.'
            )
        }
        'Relish' {
            return @(
                "Roast or soften the $($Recipe.Main) and the $($Recipe.Secondary) until sweet and tender.",
                'Cook with onion, garlic, oil, and acid until the mixture thickens.',
                "Blend or mash to the texture you want, then season with $($Recipe.Flavor).",
                'Simmer briefly again to concentrate the flavor.',
                'Cool and serve as a spread or side dish.'
            )
        }
        'Dip' {
            return @(
                "Blend or mash the $($Recipe.Main) with the $($Recipe.Secondary), oil, and a splash of acid.",
                'Thin with yogurt or water until spreadable.',
                "Fold in the seasoning blend of $($Recipe.Flavor).",
                'Taste for salt and chill briefly if you want a firmer texture.',
                'Serve with bread, vegetables, or grilled meat.'
            )
        }
        'Cake' {
            return @(
                'Heat the oven to 180 C and line or grease a tin.',
                'Whisk the sugar and eggs, then add the liquid and melted butter.',
                "Fold in the flour, the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring.",
                'Spread into the tin and bake until the center springs back.',
                'Cool slightly before slicing, adding syrup if the cake style calls for it.'
            )
        }
        'Cookie' {
            return @(
                'Heat the oven to 180 C and line a tray.',
                'Cream the butter and sugar, then add the egg.',
                "Fold in the flour with the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring.",
                'Shape into small portions and bake until just golden at the edges.',
                'Cool before storing or finishing with syrup or jam.'
            )
        }
        'Bread' {
            return @(
                'Heat the oven to 200 C and grease a loaf tin or tray.',
                'Combine the dry ingredients, then stir in the warm liquid and fat.',
                "Fold in the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring until you have a thick batter or soft dough.",
                'Spread or shape the dough in the pan.',
                'Bake until the loaf is golden and sounds hollow when tapped.'
            )
        }
        'FriedDough' {
            return @(
                'Mix the dough ingredients into a soft, slightly sticky dough or batter.',
                "Fold in the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring, then rest for 15 to 20 minutes.",
                'Heat a few centimeters of oil in a pan.',
                'Drop or shape portions into the oil and fry until puffed and deeply golden.',
                'Drain well and finish with the sweet or savory garnish that suits the dish.'
            )
        }
        'Pudding' {
            return @(
                'Bring the liquid to a gentle simmer.',
                "Add the $($Recipe.Main), the $($Recipe.Secondary), sugar, and butter.",
                "Cook slowly, stirring often, until the pudding thickens and the flavors of $($Recipe.Flavor) come through.",
                'Spoon into bowls or a serving dish.',
                'Serve warm or chilled.'
            )
        }
        'Porridge' {
            return @(
                'Bring the liquid to a simmer in a heavy pot.',
                'Whisk in the meal or bean base so it thickens without lumps.',
                "Fold in the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring.",
                'Cook on low heat until the porridge is thick, silky, and rich.',
                'Serve hot with extra butter, cheese, or yogurt.'
            )
        }
        'Skillet' {
            return @(
                'Heat the fat in a wide pan and soften the onion.',
                "Add the $($Recipe.Main) and the $($Recipe.Secondary), and cook until the mixture starts to concentrate.",
                "Season with $($Recipe.Flavor) and cook until the pan looks glossy and thick.",
                'If eggs or cheese belong in the dish, fold them through right at the end.',
                'Serve straight from the pan with bread.'
            )
        }
        'SweetBread' {
            return @(
                'Mix the dough and knead until smooth, then let it rise until doubled.',
                "Work in the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring.",
                'Shape into a braid or loaf and let it rise again.',
                'Brush with egg and bake until deeply golden.',
                'Cool before slicing so the crumb sets properly.'
            )
        }
        'Sandwich' {
            return @(
                "Cook or grill the $($Recipe.Main) and season it with $($Recipe.Flavor).",
                'Warm or toast the bread.',
                "Pile the bread with the main filling, the $($Recipe.Secondary), and the greens.",
                "Finish with $($Country.Acid) and a little oil.",
                'Serve immediately while the bread is still crisp.'
            )
        }
        'LayeredPastry' {
            return @(
                'Heat the oven to 190 C and butter the baking tin.',
                "Prepare the filling from the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring.",
                'Layer phyllo with butter and the filling, cutting the pastry before it bakes if you want clean portions.',
                'Bake until crisp and deeply golden.',
                'Finish with syrup or honey while still warm if the pastry is meant to be sweet.'
            )
        }
        'FilledDough' {
            return @(
                'Mix the dough and let it rest for 20 minutes.',
                "Prepare a filling from the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring.",
                'Roll thin, cut pieces, fill, and seal carefully.',
                'Boil or steam until tender, then coat with butter or yogurt sauce.',
                'Serve hot.'
            )
        }
        'RolledPastry' {
            return @(
                'Prepare the enriched dough and let it rise once.',
                "Spread the filling made from the $($Recipe.Main), the $($Recipe.Secondary), and the flavoring across the dough.",
                'Roll tightly, place in the pan, and let it proof again.',
                'Bake until golden and fragrant.',
                'Cool enough to slice cleanly.'
            )
        }
        default {
            return @(
                'Prepare the ingredients.',
                'Cook them using the style implied by the dish.',
                'Season well and serve.'
            )
        }
    }
}

function Get-ServingNote {
    param(
        [hashtable]$Country,
        [hashtable]$Recipe
    )

    switch ($Recipe.Type) {
        'Pie' { return "Serve warm with a spoon of yogurt and wedges of $($Country.Acid)." }
        'Soup' { return "Serve with crusty bread and a final drizzle of $($Country.Fat)." }
        'ChilledSoup' { return 'Serve very cold on a hot day or beside grilled meat.' }
        'Stew' { return 'Serve with bread, polenta, or a sharp salad.' }
        'Bake' { return 'Serve after a short rest so the tray sets and the juices settle.' }
        'Stuffed' { return 'Serve with pan juices and a spoon of yogurt or sour cream.' }
        'Grill' { return 'Serve with flatbread, onion, and a cool salad or relish.' }
        'Salad' { return 'Serve immediately while the vegetables are crisp.' }
        'Relish' { return 'Serve at room temperature as a spread or side dish.' }
        'Dip' { return 'Serve chilled or cool with bread and raw vegetables.' }
        'Cake' { return 'Serve with coffee, tea, or a small glass of dessert wine.' }
        'Cookie' { return 'Store in a tin and serve with coffee or tea.' }
        'Bread' { return 'Serve warm from the oven or toasted the next day.' }
        'FriedDough' { return 'Best eaten warm, either dusted with sugar or paired with cheese.' }
        'Pudding' { return 'Serve warm for comfort or chilled for a firmer set.' }
        'Porridge' { return 'Serve hot with extra cheese, yogurt, or butter on top.' }
        'Skillet' { return 'Bring the whole pan to the table with bread for scooping.' }
        'SweetBread' { return 'Slice once cool and serve plain or with extra jam.' }
        'Sandwich' { return 'Eat straight away while the bread and filling are both warm.' }
        'LayeredPastry' { return 'Let the pastry settle slightly before cutting neat portions.' }
        'FilledDough' { return 'Serve hot with butter, yogurt, or pan sauce spooned over.' }
        'RolledPastry' { return 'Slice after a short cooling period so the swirl holds.' }
        default { return "Serve in the style typical for $($Country.Display) home cooking." }
    }
}

function New-RecipeContent {
    param(
        [hashtable]$Country,
        [hashtable]$Recipe
    )

    $meta = Get-RecipeMeta $Recipe.Type
    $ingredients = Get-Ingredients $Country $Recipe
    $method = Get-Method $Country $Recipe
    $serving = Get-ServingNote $Country $Recipe
    $intro = "This original $($Country.Display) home-style $($Recipe.Category.ToLower()) centers on $($Recipe.Main) with $($Recipe.Secondary), seasoned with $($Recipe.Flavor). It is written for this collection and inspired by the country's broader pantry of $($Country.Signature)."

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# $($Recipe.Title)")
    $lines.Add('')
    $lines.Add("- Country: $($Country.Display)")
    $lines.Add("- Category: $($Recipe.Category)")
    $lines.Add("- Yield: $($meta.Yield)")
    $lines.Add("- Time: $($meta.Time)")
    $lines.Add('')
    $lines.Add('## Intro')
    $lines.Add($intro)
    $lines.Add('')
    $lines.Add('## Ingredients')
    foreach ($ingredient in $ingredients) {
        $lines.Add("- $ingredient")
    }
    $lines.Add('')
    $lines.Add('## Method')
    for ($index = 0; $index -lt $method.Count; $index++) {
        $lines.Add("$($index + 1). $($method[$index])")
    }
    $lines.Add('')
    $lines.Add('## Serving Note')
    $lines.Add($serving)

    return ($lines -join "`r`n")
}

$generatedPatterns = @(
    '{place} Spinach and {cheese} Pie|Pie|spinach|{cheese}|{herb} and yogurt|Savory pie',
    '{place} Leek Coil Pie|Pie|leek|{cheese}|{herb} and black pepper|Savory pie',
    '{place} Pepper Cornmeal Bake|Bake|peppers|cornmeal|garlic, yogurt, and {herb}|Savory bake',
    '{place} Herb Flatbread|Bread|{green}|yogurt|{herb}, butter, and sea salt|Flatbread',
    '{place} Potato Pan Pie|Pie|potatoes|onion|{herb} and black pepper|Savory pie',
    '{place} Yogurt Breakfast Cake|Cake|yogurt|semolina|vanilla and citrus zest|Breakfast cake',
    '{place} Mushroom and {cheese} Pastry|LayeredPastry|mushrooms|{cheese}|{herb} and butter|Savory pastry',
    '{place} Pumpkin and Onion Pie|Pie|pumpkin|onion|cinnamon, black pepper, and {herb}|Savory pie',
    '{place} White Bean Pot|Stew|white beans|tomatoes|paprika, garlic, and {herb}|Bean stew',
    '{place} Lentil and Tomato Soup|Soup|lentils|tomatoes|paprika, garlic, and {herb}|Soup',
    '{place} Chicken Rice Broth|Soup|chicken|rice|root vegetables and {herb}|Soup',
    '{place} {vegetable} and Potato Stew|Stew|{vegetable}|potatoes|paprika, onion, and {herb}|Stew',
    '{place} Cabbage and Sausage Braise|Stew|cabbage|sausage|garlic, black pepper, and paprika|Stew',
    '{place} {protein} Herb Soup|Soup|{protein}|onion|{herb}, garlic, and black pepper|Soup',
    '{place} Mushroom Barley Pot|Stew|mushrooms|barley|garlic, onion, and {herb}|Stew',
    '{place} Okra Tomato Stew|Stew|okra|tomatoes|garlic, parsley, and lemon|Vegetable stew',
    '{place} Charcoal {protein} Skewers|Grill|{protein}|onion|garlic, paprika, and {herb}|Grilled meat',
    '{place} Yogurt-Baked Chicken|Bake|chicken|yogurt|garlic, paprika, and {herb}|Baked main',
    '{place} Stuffed Peppers|Stuffed|sweet peppers|rice|beef, tomato, and {herb}|Stuffed main',
    '{place} Vine Leaf Parcels|Stuffed|vine leaves|rice|onion, lemon, and {herb}|Stuffed main',
    '{place} {fish} Tray Bake|Bake|{fish}|tomatoes|garlic, {herb}, and olive oil|Fish bake',
    '{place} Grilled Meatball Platter|Grill|{protein2}|onion|paprika, garlic, and parsley|Grilled meat',
    '{place} Eggplant Casserole|Bake|eggplant|tomatoes|garlic, onion, and {herb}|Vegetable bake',
    '{place} Festival Rice Pilaf|Bake|rice|onion|butter, broth, and {herb}|Rice main',
    '{place} Tomato Cucumber Salad|Salad|tomatoes|cucumber|onion, {herb}, and {cheese}|Salad',
    '{place} Roasted Pepper Relish|Relish|peppers|tomatoes|garlic, vinegar, and {herb}|Relish',
    '{place} Garlic Bean Mash|Dip|white beans|garlic|paprika oil and lemon|Bean dip',
    '{place} Yogurt Cucumber Dip|Dip|cucumber|yogurt|garlic, {herb}, and olive oil|Dip',
    '{place} Braised Greens|Stew|{green}|onion|garlic, olive oil, and lemon|Greens dish',
    '{place} Potato Olive Salad|Salad|potatoes|olives|parsley, onion, and {acid}|Salad',
    '{place} Charred Zucchini Salad|Salad|zucchini|yogurt|garlic, dill, and olive oil|Salad',
    '{place} Pickled Cabbage Slaw|Salad|cabbage|carrot|vinegar, pepper, and {herb}|Salad',
    '{place} Honey {nut} Cake|Cake|honey|{nut}|vanilla and citrus zest|Cake',
    '{place} Semolina Syrup Cake|Cake|semolina|yogurt|lemon syrup and vanilla|Syrup cake',
    '{place} {fruit} Tray Bake|Cake|{fruit}|walnuts|cinnamon and butter|Fruit cake',
    '{place} Rice Pudding|Pudding|rice|milk|vanilla and cinnamon|Pudding',
    '{place} Yogurt Honey Cream|Pudding|yogurt|honey|vanilla and {nut}|Cream dessert',
    '{place} {fruit} Spoon Sweet|Pudding|{fruit}|sugar syrup|cinnamon and lemon peel|Fruit dessert',
    '{place} Sesame Cookies|Cookie|sesame seeds|butter|orange zest and sugar|Cookie',
    '{place} Holiday Sweet Bread|SweetBread|{nut}|milk|citrus zest, vanilla, and butter|Sweet bread'
)

$countries = @(
    @{
        Folder = 'Albania'
        Display = 'Albania'
        Signature = 'olive oil, brined cheese, yogurt, mint, peppers, and lamb'
        Fat = 'olive oil'
        Acid = 'lemon'
        Cheese = 'brined cheese'
        Places = @('Tirana', 'Berat', 'Shkoder', 'Korca', 'Vlora', 'Gjirokaster', 'Pogradec', 'Highland')
        Proteins = @('lamb', 'chicken', 'beef', 'veal', 'sausage', 'trout')
        Vegetables = @('peppers', 'eggplant', 'potatoes', 'zucchini', 'okra', 'cabbage')
        Greens = @('spinach', 'leek', 'chard', 'herbs')
        Fish = @('trout', 'sea bass', 'sardines')
        Herbs = @('mint', 'oregano', 'parsley', 'dill')
        Fruits = @('apple', 'cherry', 'fig', 'quince')
        Nuts = @('walnut', 'almond')
        Anchors = @(
            'Tave Kosi|Bake|lamb|rice|yogurt, mint, and black pepper|Baked main',
            'Fergese e Tiranes|Skillet|peppers|brined cheese|tomato, paprika, and garlic|Skillet main',
            'Byrek me Spinaq|Pie|spinach|brined cheese|dill and yogurt|Savory pie',
            'Jani me Fasule|Stew|white beans|tomatoes|paprika, garlic, and parsley|Bean stew',
            'Speca te Mbushur|Stuffed|sweet peppers|rice|beef, mint, and tomato|Stuffed main',
            'Peshk ne Tave|Bake|trout|tomatoes|olive oil, garlic, and oregano|Fish bake',
            'Qofte Shtepie|Grill|beef and lamb mince|onion|garlic, parsley, and paprika|Grilled meat',
            'Petulla|FriedDough|yogurt|fresh cheese|olive oil and sea salt|Fried bread',
            'Trilece|Cake|milk|cream|caramel and vanilla|Milk cake',
            'Ballokume|Cookie|cornmeal|butter|orange zest and sugar|Butter cookie'
        )
    },
    @{
        Folder = 'Bosnia-and-Herzegovina'
        Display = 'Bosnia and Herzegovina'
        Signature = 'beef, lamb, peppers, yogurt sauces, and slow-cooked broths'
        Fat = 'sunflower oil'
        Acid = 'vinegar'
        Cheese = 'fresh cheese'
        Places = @('Sarajevo', 'Mostar', 'Travnik', 'Bihac', 'Banja Luka', 'Tuzla', 'Herzegovina', 'Mountain')
        Proteins = @('beef', 'lamb', 'chicken', 'veal', 'sausage', 'river fish')
        Vegetables = @('peppers', 'cabbage', 'potatoes', 'eggplant', 'okra', 'onions')
        Greens = @('spinach', 'leek', 'parsley', 'dill')
        Fish = @('river fish', 'trout', 'carp')
        Herbs = @('parsley', 'mint', 'dill', 'savory')
        Fruits = @('apple', 'pear', 'plum', 'quince')
        Nuts = @('walnut', 'hazelnut')
        Anchors = @(
            'Cevapi|Grill|beef and lamb mince|onion|garlic, paprika, and black pepper|Grilled meat',
            'Burek|Pie|beef mince|onion|paprika and parsley|Savory pie',
            'Begova Corba|Soup|chicken|okra|root vegetables and parsley|Soup',
            'Bosanski Lonac|Stew|beef|cabbage|root vegetables and smoked paprika|Stew',
            'Dolma od Paprike|Stuffed|sweet peppers|rice|beef, parsley, and tomato|Stuffed main',
            'Klepe|FilledDough|beef mince|garlic yogurt|butter and parsley|Filled dough',
            'Japrak|Stuffed|vine leaves|rice|beef, mint, and dill|Stuffed main',
            'Ustipci|FriedDough|yogurt|fresh cheese|sea salt and butter|Fried bread',
            'Tufahija|Pudding|apples|walnuts|cinnamon, cream, and syrup|Poached fruit dessert',
            'Hurmasice|Cookie|butter|semolina|sugar syrup and lemon|Syrup cookie'
        )
    },
    @{
        Folder = 'Bulgaria'
        Display = 'Bulgaria'
        Signature = 'sirene cheese, peppers, yogurt, mint, and hearty clay pot dishes'
        Fat = 'sunflower oil'
        Acid = 'vinegar'
        Cheese = 'sirene cheese'
        Places = @('Sofia', 'Plovdiv', 'Varna', 'Rhodope', 'Danube', 'Strandzha', 'Veliko Tarnovo', 'Shopluk')
        Proteins = @('pork', 'chicken', 'beef', 'lamb', 'sausage', 'trout')
        Vegetables = @('peppers', 'tomatoes', 'potatoes', 'eggplant', 'okra', 'cabbage')
        Greens = @('spinach', 'leek', 'sorrel', 'herbs')
        Fish = @('trout', 'carp', 'mackerel')
        Herbs = @('mint', 'dill', 'parsley', 'savory')
        Fruits = @('apple', 'plum', 'cherry', 'quince')
        Nuts = @('walnut', 'hazelnut')
        Anchors = @(
            'Banitsa|Pie|phyllo dough|sirene cheese|eggs and yogurt|Savory pie',
            'Shopska Salata|Salad|tomatoes|cucumber|roasted pepper, parsley, and sirene cheese|Salad',
            'Tarator|ChilledSoup|cucumber|walnuts|yogurt, garlic, and dill|Chilled soup',
            'Kavarma|Stew|pork or chicken|onion|peppers, tomato, and paprika|Clay pot stew',
            'Mish-Mash|Skillet|eggs|peppers|tomato, sirene cheese, and parsley|Skillet main',
            'Bob Chorba|Soup|white beans|carrot|paprika, mint, and tomato|Soup',
            'Sarmi|Stuffed|cabbage leaves|rice|beef, paprika, and savory herbs|Stuffed main',
            'Kebapche|Grill|minced pork and beef|onion|cumin, black pepper, and paprika|Grilled meat',
            'Tikvenik|LayeredPastry|pumpkin|walnuts|cinnamon and sugar|Sweet pastry',
            'Kozunak|SweetBread|walnuts|milk|eggs, vanilla, and citrus zest|Sweet bread'
        )
    },
    @{
        Folder = 'Croatia'
        Display = 'Croatia'
        Signature = 'olive oil, Adriatic fish, chard, cured meats, and slow braises'
        Fat = 'olive oil'
        Acid = 'lemon'
        Cheese = 'fresh cheese'
        Places = @('Zagreb', 'Dalmatian', 'Istrian', 'Split', 'Dubrovnik', 'Slavonian', 'Zadar', 'Inland')
        Proteins = @('beef', 'lamb', 'chicken', 'pork', 'sausage', 'squid')
        Vegetables = @('chard', 'peppers', 'potatoes', 'eggplant', 'zucchini', 'cabbage')
        Greens = @('chard', 'spinach', 'parsley', 'herbs')
        Fish = @('sea bass', 'sardines', 'mixed fish')
        Herbs = @('rosemary', 'parsley', 'bay leaf', 'oregano')
        Fruits = @('fig', 'cherry', 'apple', 'plum')
        Nuts = @('walnut', 'almond')
        Anchors = @(
            'Soparnik|Pie|chard|onion|olive oil and garlic|Savory pie',
            'Pasticada|Stew|beef|carrot|red wine, prunes, and rosemary|Braised main',
            'Sarma|Stuffed|cabbage leaves|rice|beef, pork, and paprika|Stuffed main',
            'Crni Rizot|Skillet|squid|rice|garlic, wine, and parsley|Rice main',
            'Brodet|Stew|mixed fish|tomatoes|garlic, wine, and bay leaf|Fish stew',
            'Strukli|RolledPastry|fresh cheese|cream|butter and nutmeg|Rolled pastry',
            'Cevapcici|Grill|beef and lamb mince|onion|garlic, paprika, and ajvar|Grilled meat',
            'Fritule|FriedDough|raisins|yogurt|citrus zest and rakija|Fried sweet',
            'Rozata|Pudding|milk|eggs|caramel, vanilla, and citrus|Custard dessert',
            'Janjetina Ispod Peke|Bake|lamb|potatoes|garlic, rosemary, and olive oil|Roast'
        )
    },
    @{
        Folder = 'Greece'
        Display = 'Greece'
        Signature = 'olive oil, lemon, oregano, feta, vegetables, and island-style sweets'
        Fat = 'olive oil'
        Acid = 'lemon'
        Cheese = 'feta'
        Places = @('Athens', 'Thessaly', 'Epirus', 'Crete', 'Pelion', 'Macedonian', 'Cycladic', 'Island')
        Proteins = @('pork', 'chicken', 'lamb', 'beef', 'goat', 'sea bass')
        Vegetables = @('eggplant', 'zucchini', 'potatoes', 'tomatoes', 'peppers', 'okra')
        Greens = @('spinach', 'leek', 'greens', 'herbs')
        Fish = @('sea bass', 'sardines', 'anchovies')
        Herbs = @('oregano', 'dill', 'parsley', 'mint')
        Fruits = @('fig', 'orange', 'apple', 'cherry')
        Nuts = @('walnut', 'almond')
        Anchors = @(
            'Moussaka|Bake|eggplant|potatoes|beef, cinnamon, and bechamel|Baked main',
            'Spanakopita|Pie|spinach|feta|dill and olive oil|Savory pie',
            'Fasolada|Soup|white beans|tomatoes|carrot, celery, and oregano|Soup',
            'Souvlaki|Grill|pork or chicken|flatbread|oregano, garlic, and lemon|Grilled meat',
            'Gemista|Stuffed|tomatoes and peppers|rice|herbs, olive oil, and pine nuts|Stuffed main',
            'Dolmades|Stuffed|vine leaves|rice|lemon, dill, and onion|Stuffed main',
            'Briam|Bake|zucchini|potatoes|tomato, garlic, and oregano|Vegetable bake',
            'Tzatziki|Dip|cucumber|yogurt|garlic, dill, and olive oil|Dip',
            'Revani|Cake|semolina|yogurt|lemon syrup and vanilla|Syrup cake',
            'Loukoumades|FriedDough|honey|walnuts|cinnamon and sugar|Fried sweet'
        )
    },
    @{
        Folder = 'Kosovo'
        Display = 'Kosovo'
        Signature = 'lamb, dairy, peppers, layered breads, and family-style tray bakes'
        Fat = 'sunflower oil'
        Acid = 'lemon'
        Cheese = 'brined cheese'
        Places = @('Prizren', 'Peja', 'Pristina', 'Gjakova', 'Rugova', 'Dukagjin', 'Shar', 'Village')
        Proteins = @('lamb', 'beef', 'chicken', 'veal', 'sausage', 'trout')
        Vegetables = @('peppers', 'eggplant', 'potatoes', 'cabbage', 'zucchini', 'okra')
        Greens = @('spinach', 'leek', 'chard', 'herbs')
        Fish = @('trout', 'carp', 'river fish')
        Herbs = @('mint', 'parsley', 'dill', 'oregano')
        Fruits = @('apple', 'cherry', 'fig', 'plum')
        Nuts = @('walnut', 'hazelnut')
        Anchors = @(
            'Flija|Bake|cream|butter|yogurt and layered batter|Layered bake',
            'Pite me Spinaq|Pie|spinach|brined cheese|dill and black pepper|Savory pie',
            'Leqenik|Bread|leeks|cornmeal|yogurt and butter|Corn bread',
            'Tav Prizreni|Bake|lamb|peppers|tomato, onion, and garlic|Baked main',
            'Qebapa|Grill|beef and lamb mince|onion|garlic, paprika, and kajmak|Grilled meat',
            'Speca te Mbushur|Stuffed|sweet peppers|rice|beef, mint, and tomato|Stuffed main',
            'Fasule me Mish|Stew|white beans|beef|paprika, garlic, and parsley|Bean stew',
            'Petulla te Shtepise|FriedDough|yogurt|fresh cheese|butter and sea salt|Fried bread',
            'Bakllava|LayeredPastry|walnuts|butter|honey and cinnamon|Layered pastry',
            'Sheqerpare|Cookie|semolina|butter|sugar syrup and lemon|Syrup cookie'
        )
    },
    @{
        Folder = 'Montenegro'
        Display = 'Montenegro'
        Signature = 'mountain dairy, lamb, smoked meat, cornmeal, and coastal frying'
        Fat = 'olive oil'
        Acid = 'lemon'
        Cheese = 'fresh cheese'
        Places = @('Cetinje', 'Njegusi', 'Kotor', 'Durmitor', 'Podgorica', 'Bar', 'Lake Skadar', 'Mountain')
        Proteins = @('lamb', 'beef', 'pork', 'veal', 'smoked meat', 'river fish')
        Vegetables = @('peppers', 'potatoes', 'cabbage', 'eggplant', 'zucchini', 'collard greens')
        Greens = @('spinach', 'leek', 'collard greens', 'herbs')
        Fish = @('river fish', 'trout', 'sea bass')
        Herbs = @('parsley', 'mint', 'dill', 'rosemary')
        Fruits = @('fig', 'apple', 'plum', 'cherry')
        Nuts = @('walnut', 'almond')
        Anchors = @(
            'Kacamak|Porridge|potatoes|kajmak|cornmeal, butter, and cheese|Hearty porridge',
            'Cicvara|Porridge|cheese|yogurt|cornmeal and butter|Creamy porridge',
            'Njeguski Steak|Bake|pork or veal|ham and cheese|mustard, cream, and black pepper|Baked main',
            'Jagnjetina u Mlijeku|Stew|lamb|milk|garlic, carrots, and parsley|Braised main',
            'Punjene Paprike|Stuffed|sweet peppers|rice|beef, tomato, and parsley|Stuffed main',
            'Riblja Corba|Soup|river fish|tomatoes|paprika, celery, and garlic|Soup',
            'Rastan sa Mesom|Stew|collard greens|smoked meat|garlic, potato, and black pepper|Stew',
            'Priganice|FriedDough|yogurt|fresh cheese|honey and sea salt|Fried bread',
            'Krostule|FriedDough|eggs|sugar|citrus zest and vanilla|Crisp pastry',
            'Cevapi sa Kajmakom|Grill|beef mince|onion|kajmak, paprika, and garlic|Grilled meat'
        )
    },
    @{
        Folder = 'North-Macedonia'
        Display = 'North Macedonia'
        Signature = 'beans, peppers, yogurt, grilled meats, and bright paprika'
        Fat = 'sunflower oil'
        Acid = 'vinegar'
        Cheese = 'sirene cheese'
        Places = @('Skopje', 'Ohrid', 'Bitola', 'Tetovo', 'Strumica', 'Tikvesh', 'Pelister', 'Vardar')
        Proteins = @('beef', 'lamb', 'chicken', 'veal', 'sausage', 'trout')
        Vegetables = @('peppers', 'eggplant', 'potatoes', 'tomatoes', 'okra', 'cabbage')
        Greens = @('spinach', 'leek', 'sorrel', 'herbs')
        Fish = @('trout', 'carp', 'river fish')
        Herbs = @('mint', 'parsley', 'dill', 'savory')
        Fruits = @('apple', 'quince', 'cherry', 'plum')
        Nuts = @('walnut', 'hazelnut')
        Anchors = @(
            'Tavce Gravce|Bake|white beans|onion|paprika, mint, and dried pepper|Baked beans',
            'Makedonska Salata|Salad|tomatoes|cucumber|roasted pepper, onion, and sirene cheese|Salad',
            'Pastrmajlija|Pie|bread dough|beef or lamb|paprika and black pepper|Open pie',
            'Zelnik|Pie|leeks|sirene cheese|spinach and butter|Savory pie',
            'Polneti Piperki|Stuffed|sweet peppers|rice|beef, paprika, and tomato|Stuffed main',
            'Turli Tava|Bake|eggplant|potatoes|tomato, peppers, and parsley|Vegetable bake',
            'Kebapi|Grill|beef mince|onion|paprika, cumin, and garlic|Grilled meat',
            'Tarator|ChilledSoup|cucumber|walnuts|yogurt, garlic, and dill|Chilled soup',
            'Sutlijash|Pudding|rice|milk|cinnamon and vanilla|Rice pudding',
            'Tulumbi|FriedDough|choux paste|syrup|lemon and vanilla|Syrup pastry'
        )
    },
    @{
        Folder = 'Romania'
        Display = 'Romania'
        Signature = 'sour soups, cornmeal, roasted peppers, pork, and nut-rich baking'
        Fat = 'sunflower oil'
        Acid = 'vinegar'
        Cheese = 'brined cheese'
        Places = @('Transylvanian', 'Bucharest', 'Brasov', 'Banat', 'Dobruja', 'Maramures', 'Moldavian', 'Wallachian')
        Proteins = @('pork', 'beef', 'chicken', 'lamb', 'sausage', 'trout')
        Vegetables = @('peppers', 'eggplant', 'potatoes', 'cabbage', 'zucchini', 'onions')
        Greens = @('lovage', 'spinach', 'leek', 'herbs')
        Fish = @('trout', 'carp', 'mackerel')
        Herbs = @('lovage', 'dill', 'parsley', 'thyme')
        Fruits = @('apple', 'plum', 'cherry', 'quince')
        Nuts = @('walnut', 'hazelnut')
        Anchors = @(
            'Sarmale|Stuffed|cabbage leaves|rice|pork, dill, and tomato|Stuffed main',
            'Ciorba de Burta|Soup|tripe|sour cream|garlic, vinegar, and carrot|Soup',
            'Mamaliga cu Branza|Porridge|brined cheese|sour cream|cornmeal and butter|Porridge',
            'Mici|Grill|beef and lamb mince|onion|garlic, thyme, and paprika|Grilled meat',
            'Fasole Batuta|Dip|white beans|garlic|caramelized onion and paprika oil|Bean dip',
            'Ciorba de Perisoare|Soup|meatballs|rice|root vegetables and lovage|Soup',
            'Zacusca|Relish|eggplant|roasted peppers|tomato, onion, and bay leaf|Relish',
            'Drob de Miel|Bake|lamb offal|greens|eggs, dill, and parsley|Baked main',
            'Cozonac|SweetBread|walnuts|milk|cocoa, citrus zest, and vanilla|Sweet bread',
            'Papanasi|FriedDough|fresh cheese|berry jam|sour cream and vanilla|Fried dessert'
        )
    },
    @{
        Folder = 'Serbia'
        Display = 'Serbia'
        Signature = 'beans, grilled meat, paprika, corn breads, and robust tray bakes'
        Fat = 'sunflower oil'
        Acid = 'vinegar'
        Cheese = 'white cheese'
        Places = @('Belgrade', 'Sumadija', 'Nis', 'Vojvodina', 'Kopaonik', 'Morava', 'Zlatibor', 'Village')
        Proteins = @('beef', 'pork', 'chicken', 'lamb', 'sausage', 'river fish')
        Vegetables = @('peppers', 'eggplant', 'potatoes', 'cabbage', 'zucchini', 'onions')
        Greens = @('spinach', 'leek', 'sorrel', 'herbs')
        Fish = @('river fish', 'trout', 'carp')
        Herbs = @('parsley', 'dill', 'mint', 'savory')
        Fruits = @('apple', 'plum', 'cherry', 'quince')
        Nuts = @('walnut', 'hazelnut')
        Anchors = @(
            'Sarma|Stuffed|cabbage leaves|rice|beef, pork, and paprika|Stuffed main',
            'Cevapi|Grill|beef mince|onion|garlic, paprika, and kajmak|Grilled meat',
            'Karadjordjeva Snicla|Bake|veal or pork|kajmak|breadcrumbs, lemon, and parsley|Baked main',
            'Prebranac|Bake|white beans|onion|paprika, oil, and bay leaf|Baked beans',
            'Gibanica|Pie|phyllo dough|white cheese|eggs, yogurt, and butter|Savory pie',
            'Pljeskavica|Grill|beef and pork mince|onion|paprika, garlic, and ajvar|Grilled meat',
            'Punjene Paprike|Stuffed|sweet peppers|rice|beef, tomato, and parsley|Stuffed main',
            'Riblja Corba|Soup|river fish|tomatoes|paprika, celery, and garlic|Soup',
            'Vanilice|Cookie|butter|jam|vanilla sugar and lemon zest|Sandwich cookie',
            'Proja|Bread|white cheese|yogurt|cornmeal and butter|Corn bread'
        )
    },
    @{
        Folder = 'Slovenia'
        Display = 'Slovenia'
        Signature = 'beans, sauerkraut, buckwheat, dairy, and alpine pastry traditions'
        Fat = 'pumpkin seed oil'
        Acid = 'vinegar'
        Cheese = 'fresh cheese'
        Places = @('Ljubljana', 'Karst', 'Alpine', 'Piran', 'Prekmurje', 'Idrija', 'Styria', 'Soca')
        Proteins = @('pork', 'beef', 'chicken', 'sausage', 'lamb', 'trout')
        Vegetables = @('sauerkraut', 'potatoes', 'cabbage', 'mushrooms', 'peppers', 'beans')
        Greens = @('spinach', 'chives', 'parsley', 'herbs')
        Fish = @('trout', 'sea bass', 'carp')
        Herbs = @('chives', 'parsley', 'caraway', 'thyme')
        Fruits = @('apple', 'pear', 'plum', 'cherry')
        Nuts = @('walnut', 'hazelnut')
        Anchors = @(
            'Jota|Soup|beans|sauerkraut|potatoes, garlic, and bay leaf|Soup',
            'Kranjska Klobasa s Kislim Zeljem|Stew|sausage|sauerkraut|caraway and black pepper|Stew',
            'Idrijski Zlikrofi|FilledDough|potatoes|onion|chives and butter|Filled dough',
            'Potica|RolledPastry|walnuts|honey|sweet dough and cinnamon|Rolled pastry',
            'Prekmurska Gibanica|LayeredPastry|apples|poppy seeds|walnuts, quark, and raisins|Layered pastry',
            'Struklji|RolledPastry|fresh cheese|cream|herbs and butter|Rolled pastry',
            'Bograc|Stew|beef and pork|potatoes|paprika, wine, and garlic|Stew',
            'Matevz|Porridge|beans|potatoes|garlic, cracklings, and pepper|Bean mash',
            'Ajdovi Zganci|Porridge|buckwheat flour|onion|butter and cracklings|Rustic porridge',
            'Krofi|FriedDough|jam|vanilla sugar|lemon zest and butter|Fried sweet'
        )
    },
    @{
        Folder = 'Turkey'
        Display = 'Turkey'
        Signature = 'olive oil, peppers, bulgur, yogurt, grilled meats, and syrup sweets'
        Fat = 'olive oil'
        Acid = 'lemon'
        Cheese = 'white cheese'
        Places = @('Edirne', 'Thracian', 'Tekirdag', 'Gallipoli', 'Bursa', 'Istanbul', 'Aegean', 'Village')
        Proteins = @('beef', 'lamb', 'chicken', 'veal', 'fish', 'sausage')
        Vegetables = @('eggplant', 'peppers', 'tomatoes', 'zucchini', 'okra', 'cabbage')
        Greens = @('parsley', 'mint', 'dill', 'spinach')
        Fish = @('sea bass', 'mackerel', 'sardines')
        Herbs = @('mint', 'parsley', 'oregano', 'dill')
        Fruits = @('fig', 'quince', 'cherry', 'apple')
        Nuts = @('walnut', 'pistachio')
        Anchors = @(
            'Imam Bayildi|Bake|eggplant|onion|tomato, garlic, and olive oil|Vegetable bake',
            'Kisir|Salad|bulgur|tomatoes|parsley, pomegranate molasses, and mint|Salad',
            'Menemen|Skillet|eggs|peppers|tomato, olive oil, and oregano|Skillet main',
            'Kuru Fasulye|Stew|white beans|tomatoes|butter, paprika, and onion|Bean stew',
            'Karniyarik|Stuffed|eggplant|beef mince|tomato, parsley, and garlic|Stuffed main',
            'Yaprak Sarma|Stuffed|vine leaves|rice|pine nuts, mint, and lemon|Stuffed main',
            'Izgara Kofte|Grill|beef mince|onion|cumin, paprika, and parsley|Grilled meat',
            'Balik Ekmek|Sandwich|grilled fish|bread|onion, greens, and lemon|Street sandwich',
            'Revani|Cake|semolina|yogurt|citrus syrup and vanilla|Syrup cake',
            'Sutlac|Pudding|rice|milk|vanilla and cinnamon|Rice pudding'
        )
    }
)

if (-not (Test-Path $cookbookRoot)) {
    New-Item -ItemType Directory -Path $cookbookRoot | Out-Null
}

$tocLines = [System.Collections.Generic.List[string]]::new()
$tocLines.Add('# Balkan Cookbook Table of Contents')
$tocLines.Add('')
$tocLines.Add('This table of contents was generated by `tools/generate-cookbook.ps1`. Each country folder under `cookbook/` contains exactly 50 original recipe markdown files.')

foreach ($country in $countries) {
    $countryFolder = Join-Path $cookbookRoot $country.Folder
    if (-not (Test-Path $countryFolder)) {
        New-Item -ItemType Directory -Path $countryFolder | Out-Null
    }

    Get-ChildItem -Path $countryFolder -Filter '*.md' -File -ErrorAction SilentlyContinue | Remove-Item -Force

    $recipes = [System.Collections.Generic.List[hashtable]]::new()
    for ($index = 0; $index -lt $country.Anchors.Count; $index++) {
        $recipes.Add((Convert-RecipeString $country.Anchors[$index] $country $index))
    }
    for ($index = 0; $index -lt $generatedPatterns.Count; $index++) {
        $recipes.Add((Convert-RecipeString $generatedPatterns[$index] $country $index))
    }

    if ($recipes.Count -ne 50) {
        throw "Expected 50 recipes for $($country.Display), found $($recipes.Count)."
    }

    $tocLines.Add('')
    $tocLines.Add("## $($country.Display)")

    for ($index = 0; $index -lt $recipes.Count; $index++) {
        $recipe = $recipes[$index]
        $fileName = ('{0:d2}-{1}.md' -f ($index + 1), (New-Slug $recipe.Title))
        $filePath = Join-Path $countryFolder $fileName
        $content = New-RecipeContent $country $recipe
        Set-Content -Path $filePath -Value $content -Encoding utf8
        $tocLines.Add("$($index + 1). [$($recipe.Title)]($($country.Folder)/$fileName)")
    }
}

$tocLines.Add('')
$tocLines.Add('Generated on May 31, 2026.')
Set-Content -Path (Join-Path $cookbookRoot 'TABLE-OF-CONTENTS.md') -Value ($tocLines -join "`r`n") -Encoding utf8