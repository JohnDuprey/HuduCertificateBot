#Region './Private/Get-HuduCompanyFolders.ps1' 0
function Get-HuduCompanyFolders {
    [CmdletBinding()]
    Param (
        [PSCustomObject]$FoldersRaw
    )
   
    $RootFolders = $FoldersRaw | Where-Object { $null -eq $_.parent_folder_id }
    $ReturnObject = [PSCustomObject]@{}
    foreach ($folder in $RootFolders) {
        $SubFolders = Get-HuduSubFolders -id $folder.id -FoldersRaw $FoldersRaw
        foreach ($SubFolder in $SubFolders) {
            $Folder | add-member -Membertype NoteProperty -Name $(Get-HuduFolderCleanName $($SubFolder.PSObject.Properties.name)) -Value $SubFolder.PSObject.Properties.value
        }
        $ReturnObject | add-member -Membertype NoteProperty -Name $(Get-HuduFolderCleanName $($folder.name)) -Value $folder
    }
    return $ReturnObject
}
#EndRegion './Private/Get-HuduCompanyFolders.ps1' 18
#Region './Private/Get-HuduFolderCleanName.ps1' 0
function Get-HuduFolderCleanName {
    [CmdletBinding()]
    param(
        [string]$Name
    )

    $FieldNames = @("id", "company_id", "icon", "description", "name", "parent_folder_id", "created_at", "updated_at")

    if ($Name -in $FieldNames) {
        Return "fld_$Name"
    } else {
        Return $Name
    }

}
#EndRegion './Private/Get-HuduFolderCleanName.ps1' 16
#Region './Private/Get-HuduSubFolders.ps1' 0
function Get-HuduSubFolders {
    [CmdletBinding()]
    Param(
        [int]$id,
        [PSCustomObject]$FoldersRaw
    )

    $SubFolders = $FoldersRaw | where-Object { $_.parent_folder_id -eq $id } 
    $ReturnFolders = [System.Collections.ArrayList]@()
    foreach ($Folder in $SubFolders) {
        $SubSubFolders = Get-HuduSubFolders -id $Folder.id -FoldersRaw $FoldersRaw
        foreach ($AddFolder in $SubSubFolders) {
            $null = $folder | add-member -Membertype NoteProperty -Name $(Get-HuduFolderCleanName $($AddFolder.PSObject.Properties.name)) -Value $AddFolder.PSObject.Properties.value
        }
        $ReturnObject = [PSCustomObject]@{
            $(Get-HuduFolderCleanName $($Folder.name)) = $Folder
        }
        $null = $ReturnFolders.add($ReturnObject)
    }

    return $ReturnFolders

}
#EndRegion './Private/Get-HuduSubFolders.ps1' 24
#Region './Private/Invoke-HuduRequest.ps1' 0
function Invoke-HuduRequest {
	[CmdletBinding()]
	Param(
		[string]$Method,
		[string]$Resource,
		[string]$Body
	)
	
	write-verbose "Method: $Method"
	write-verbose "Resource: $Resource"
	write-verbose "Body: $($Body | out-string)"
	write-verbose "BaseURL: $(Get-HuduBaseURL)"

	try {
		if (($Method -eq "put") -or ($Method -eq "post") -or ($Method -eq "delete")) {
			$HuduAPIKey = Get-HuduApiKey
			$HuduBaseURL = Get-HuduBaseURL
			$HuduResult = Invoke-RestMethod -method $method -uri ($HuduBaseURL + $Resource) `
				-headers @{'x-api-key' = (New-Object PSCredential "user", $HuduAPIKey).GetNetworkCredential().Password; } `
				-ContentType 'application/json; charset=utf-8' -body $Body			

		} else {	
			$HuduAPIKey = Get-HuduApiKey
			$HuduBaseURL = Get-HuduBaseURL
			$HuduResult = Invoke-RestMethod -method $method -uri ($HuduBaseURL + $Resource) `
				-headers @{'x-api-key' = (New-Object PSCredential "user", $HuduAPIKey).GetNetworkCredential().Password; } `
				-ContentType 'application/json; charset=utf-8'
		}


	} catch {
		if ("$_".trim() -eq "Retry later" -or "$_".trim() -eq "The remote server returned an error: (429) Too Many Requests.") {
			Write-Host "Hudu API Rate limited. Waiting 30 Seconds then trying again" -foregroundcolor red
			Start-Sleep 30
			$HuduResult = Invoke-HuduRequest -Method $method -Resource $resource -Body $Body
		} else {
			Write-Error "'$_'"
		}
	}
	
	return $HuduResult
	
}
#EndRegion './Private/Invoke-HuduRequest.ps1' 44
#Region './Public/Get-HuduActivityLogs.ps1' 0
function Get-HuduActivityLogs {
	[CmdletBinding()]
	Param (
		[Alias("user_id")]
		[Int]$UserId = '',
		[Alias("user_email")]
		[String]$UserEmail = '',
		[Alias("resource_id")]
		[Int]$ResourceId = '',
		[Alias("resource_type")]
		[String]$ResourceType = '',
		[Alias("action_message")]
		[String]$ActionMessage = '',
		[Alias("start_date")]
		[DateTime]$StartDate,
		[Alias("end_date")]
		[DateTime]$EndDate	
	)
	
	$ResourceFilter = ''
	
	if ($UserId) {
		$ResourceFilter = "$($ResourceFilter)&user_id=$($UserId)"
	}
	
	if ($UserEmail) {
		$ResourceFilter = "$($ResourceFilter)&user_email=$($UserEmail)"
	}
	
	if ($ResourceId) {
		$ResourceFilter = "$($ResourceFilter)&resource_id=$($ResourceId)"
	}
	
	if ($ResourceType) {
		$ResourceFilter = "$($ResourceFilter)&resource_type=$($ResourceType)"
	}
	
	if ($ActionMessage) {
		$ResourceFilter = "$($ResourceFilter)&action_message=$($ActionMessage)"
	}

	if ($StartDate) {
		$ISO8601Date = $StartDate.ToString("o");
		$ResourceFilter = "$($ResourceFilter)&start_date=$($ISO8601Date)"
	}
	
	$i = 1;
		
	$AllActivity = do {
		$Activity = Invoke-HuduRequest -Method get -Resource "/api/v1/activity_logs?page=$i&page_size=1000$($ResourceFilter)"
		$i++
		$Activity
	} while ($Activity.count % 1000 -eq 0 -and $Activity.count -ne 0)
		 
    
	if ($EndDate) {
		$AllActivity = $AllActivity | where-object { $([DateTime]::Parse($_.created_at)) -le $EndDate }
	}

	return $AllActivity
	
}
#EndRegion './Public/Get-HuduActivityLogs.ps1' 63
#Region './Public/Get-HuduApiKey.ps1' 0
function Get-HuduApiKey {
	[CmdletBinding()]
	Param()
	if ($null -eq $Int_HuduAPIKey) {
		Write-Error "No API key has been set. Please use New-HuduAPIKey to set it."
	} else {
		$Int_HuduAPIKey
	}
}
#EndRegion './Public/Get-HuduApiKey.ps1' 10
#Region './Public/Get-HuduAppInfo.ps1' 0
function Get-HuduAppInfo {
    [CmdletBinding()]
    Param()
    try {
    
        $HuduAPIKey = Get-HuduApiKey
        $HuduBaseURL = Get-HuduBaseURL
	
        $version = Invoke-RestMethod -method get -uri ($HuduBaseURL + "/api/v1/api_info") `
            -headers @{'x-api-key' = (New-Object PSCredential "user", $HuduAPIKey).GetNetworkCredential().Password; } `
            -ContentType 'application/json'
		

    } catch {
        $version = @{
            version = "0.0.0.0"
            date    = "2000-01-01"
        }
    }


    return $Version
	
}
#EndRegion './Public/Get-HuduAppInfo.ps1' 25
#Region './Public/Get-HuduArticles.ps1' 0
function Get-HuduArticles {
	[CmdletBinding()]
	Param (
		[Int]$Id = '',
		[Alias("company_id")]
		[Int]$CompanyId = '',
		[String]$Name = '',
		[String]$Slug
	)
	
	if ($Id) {
		$Article = Invoke-HuduRequest -Method get -Resource "/api/v1/articles/$Id"
		return $Article
	} else {

		$ResourceFilter = ''

		if ($CompanyId) {
			$ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
		}

		if ($Name) {
			$ResourceFilter = "$($ResourceFilter)&name=$($Name)"
		}

		if ($Slug) {
			$ResourceFilter = "$($ResourceFilter)&slug=$($Slug)"
		}	
	
		$i = 1;
		$AllArticles = do {
			$Articles = Invoke-HuduRequest -Method get -Resource "/api/v1/articles?page=$i&page_size=1000$($ResourceFilter)"
			$i++
			$Articles.Articles
		} while ($Articles.Articles.count % 1000 -eq 0 -and $Articles.Articles.count -ne 0)
		
		return $AllArticles
	
	}
}
#EndRegion './Public/Get-HuduArticles.ps1' 41
#Region './Public/Get-HuduAssetLayoutFieldID.ps1' 0
function Get-HuduAssetLayoutFieldID {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[Alias("asset_layout_id")]
		[Parameter(Mandatory = $true)]
		[Int]$LayoutId
	)
	
	$Layout = Get-HuduAssetLayouts -layoutid $LayoutId
	
	$Fields = [Collections.Generic.List[Object]]($Layout.fields)
	$Index = $Fields.FindIndex( { $args[0].label -eq $Name } )
	$Fields[$Index].id
	
}
#EndRegion './Public/Get-HuduAssetLayoutFieldID.ps1' 18
#Region './Public/Get-HuduAssetLayouts.ps1' 0
function Get-HuduAssetLayouts {
	[CmdletBinding()]
	Param (
		[String]$Name,
		[Alias("id", "layout_id")]
		[String]$LayoutId,
		[String]$Slug
	)
	
	if ($LayoutId) {
		$AssetLayout = Invoke-HuduRequest -Method get -Resource "/api/v1/asset_layouts/$($LayoutId)"
		return $AssetLayout.asset_layout
	} else {

		$ResourceFilter = ''

		if ($Name) {
			$ResourceFilter = "$($ResourceFilter)&name=$($Name)"
		}
		
		if ($Slug) {
			$ResourceFilter = "$($ResourceFilter)&slug=$($Slug)"
		}	
		
		$i = 1;
		$AllAssetLayouts = do {
			$AssetLayouts = Invoke-HuduRequest -Method get -Resource "/api/v1/asset_layouts?page=$i&page_size=25$($ResourceFilter)"
			$i++
			$AssetLayouts.Asset_Layouts
		} while ($AssetLayouts.asset_layouts.count % 25 -eq 0 -and $AssetLayouts.asset_layouts.count -ne 0)
		
		return $AllAssetLayouts
	}
}
#EndRegion './Public/Get-HuduAssetLayouts.ps1' 35
#Region './Public/Get-HuduAssets.ps1' 0
function Get-HuduAssets {
	[CmdletBinding()]
	Param (
		[Int]$Id = '',
		[Alias('asset_layout_id')]
		[Int]$AssetLayoutId = '',
		[Alias('company_id')]
		[Int]$CompanyId = '',
		[String]$Name = '',
		[Bool]$Archived = $false,
		[Alias('primary_serial')]
		[String]$PrimarySerial = '',
		[String]$Slug
	)
	

	if ($id -and $CompanyId) {
		$Asset = Invoke-HuduRequest -Method get -Resource "/api/v1/companies/$CompanyId/assets/$Id"
		return $Asset
	}
 else {

		$ResourceFilter = ''
	
		if ($CompanyId) {
			$ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
		}
	
		if ($AssetLayoutId) {
			$ResourceFilter = "$($ResourceFilter)&asset_layout_id=$($AssetLayoutId)"
		}
	
		if ($Name) {
			$ResourceFilter = "$($ResourceFilter)&name=$($Name)"
		}

		if ($Archived) {
			$ResourceFilter = "$($ResourceFilter)&archived=$($Archived)"
		}

		if ($PrimarySerial) {
			$ResourceFilter = "$($ResourceFilter)&primary_serial=$($PrimarySerial)"
		}

		if ($Id) {
			$ResourceFilter = "$($ResourceFilter)&id=$($Id)"
		}	

		if ($Slug) {
			$ResourceFilter = "$($ResourceFilter)&slug=$($Slug)"
		}	
	
		$i = 1;
		$AllAssets = do {
			$Assets = Invoke-HuduRequest -Method get -Resource "/api/v1/assets?page=$i&page_size=1000$($ResourceFilter)"
			$i++
			$Assets.Assets
		} while ($Assets.Assets.count % 1000 -eq 0 -and $Assets.Assets.count -ne 0)
		
		return $AllAssets
	}
}
 
#EndRegion './Public/Get-HuduAssets.ps1' 64
#Region './Public/Get-HuduBaseURL.ps1' 0
function Get-HuduBaseURL {
	[CmdletBinding()]
	Param()
	if ($null -eq $Int_HuduBaseURL) {
		Write-Error "No Base URL has been set. Please use New-HuduBaseURL to set it."
	} else {
		$Int_HuduBaseURL
	}
}
#EndRegion './Public/Get-HuduBaseURL.ps1' 10
#Region './Public/Get-HuduCard.ps1' 0
function Get-HuduCard {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[Alias("integration_slug")]
		[String]$IntegrationSlug,
		[Alias("integration_id")]
		[String]$IntegrationId = '',
		[Alias("integration_identifier")]
		[String]$IntegrationIdentifier = ''
	
	)
	
	
	$ResourceFilter = "&integration_slug=$($IntegrationSlug)"

	if ($IntegrationId) {
		$ResourceFilter = "$($ResourceFilter)&integration_id=$($IntegrationId)"
	}

	if ($IntegrationIdentifier) {
		$ResourceFilter = "$($ResourceFilter)&integration_identifier=$($IntegrationIdentifier)"
	}

	$i = 1;
	$AllCards = do {
		$Cards = Invoke-HuduRequest -Method get -Resource "/api/v1/cards/lookup?page=$i&page_size=1000$($ResourceFilter)"
		$i++
		$Cards.integrator_cards
	} while ($Cards.integrator_cards.count % 1000 -eq 0 -and $Cards.integrator_cards.count -ne 0)
	

	return $AllCards
	
}
#EndRegion './Public/Get-HuduCard.ps1' 36
#Region './Public/Get-HuduCompanies.ps1' 0
function Get-HuduCompanies {
	[CmdletBinding()]
	Param (
		[String]$Name = '',
		[Alias("phone_number")]
		[String]$PhoneNumber = '',
		[String]$Website = '',
		[String]$City = '',
		[String]$State = '',
		[Alias("id_in_integration")]
		[Int]$IdInIntegration = '',
		[Int]$Id = '',
		[String]$Slug
	)


	if ($Id) {
		$Company = Invoke-HuduRequest -Method get -Resource "/api/v1/companies/$Id"
		return $Company
	} else {
	
		$ResourceFilter = ''
	
		if ($Name) {
			$ResourceFilter = "$($ResourceFilter)&name=$($Name)"
		}
	
		if ($PhoneNumber) {
			$ResourceFilter = "$($ResourceFilter)&phone_number=$($PhoneNumber)"
		}
	
		if ($Website) {
			$ResourceFilter = "$($ResourceFilter)&website=$($Website)"
		}
	
		if ($City) {
			$ResourceFilter = "$($ResourceFilter)&city=$($City)"
		}
	
		if ($City) {
			$ResourceFilter = "$($ResourceFilter)&state=$($City)"
		}
	
		if ($IdInIntegration) {
			$ResourceFilter = "$($ResourceFilter)&id_in_integration=$($IdInIntegration)"
		}
	
		if ($Slug) {
			$ResourceFilter = "$($ResourceFilter)&slug=$($Slug)"
		}	
	
		$i = 1;
		$AllCompanies = do {
			$Companies = Invoke-HuduRequest -Method get -Resource "/api/v1/companies?page=$i&page_size=1000$($ResourceFilter)"
			$i++
			$Companies.Companies
		} while ($Companies.Companies.count % 1000 -eq 0 -and $Companies.Companies.count -ne 0)
		
			
		return $AllCompanies
	
	}
}
#EndRegion './Public/Get-HuduCompanies.ps1' 64
#Region './Public/Get-HuduExpirations.ps1' 0
function Get-HuduExpirations {
    [CmdletBinding()]
    Param (
        [Alias('company_id')]
        [Int]$CompanyId = '',
        [Alias('expiration_type')]
        [String]$ExpirationType = '',
        [Alias('resource_id')]
        [Int]$ResourceId = '',
        [Alias('resource_type')]
        [String]$ResourceType = ''
    )

    $ResourceFilter = ''

    if ($CompanyId) {
        $ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
    }
    if ($ExpirationType) {
        $ResourceFilter = "$($ResourceFilter)&expiration_type=$($ExpirationType)"
    }
    if ($ResourceType) {
        $ResourceFilter = "$($ResourceFilter)&resource_type=$($ResourceType)"
    }
    if ($ResourceId) {
        $ResourceFilter = "$($ResourceFilter)&resource_id=$($ResourceId)"
    }

    $i = 1;

    $AllExpirations = do {
        $Expirations = Invoke-HuduRequest -Method GET -Resource "/api/v1/expirations?page=$i&page_size=1000$($ResourceFilter)"
        $i++
        $Expirations
    } while ($Expirations.count % 1000 -eq 0 -and $Expirations.count -ne 0)

    return $AllExpirations
}
#EndRegion './Public/Get-HuduExpirations.ps1' 39
#Region './Public/Get-HuduFolderMap.ps1' 0
function Get-HuduFolderMap {
	[CmdletBinding()]
	Param (
		[Alias("company_id")]
		[Int]$CompanyId = ''
	)
	
	if ($CompanyId) {
		$FoldersRaw = Get-HuduFolders -company_id $CompanyId
		$SubFolders = Get-HuduCompanyFolders -FoldersRaw $FoldersRaw

	} else {
		$FoldersRaw = Get-HuduFolders
		$FoldersProcessed = $FoldersRaw | where-Object { $null -eq $_.company_id }
		$SubFolders = Get-HuduCompanyFolders -FoldersRaw $FoldersProcessed
	}

	return $SubFolders
}
#EndRegion './Public/Get-HuduFolderMap.ps1' 20
#Region './Public/Get-HuduFolders.ps1' 0
function Get-HuduFolders {
	[CmdletBinding()]
	Param (
		[Int]$Id = '',
		[Int]$Name = '',
		[Alias("company_id")]
		[Int]$CompanyId = ''
	)
	
	if ($id) {
		$Folder = Invoke-HuduRequest -Method get -Resource "/api/v1/folders/$id"
		return $Folder.Folder
	} else {

		$ResourceFilter = ''
	
		if ($CompanyId) {
			$resourcefilter = "$($ResourceFilter)&company_id=$($CompanyId)"
		}
	
		if ($Name) {
			$ResourceFilter = "$($ResourceFilter)&name=$($Name)"
		}
	
		$i = 1;
		$AllFolders = do {
			$Folders = Invoke-HuduRequest -Method get -Resource "/api/v1/folders?page=$i&page_size=1000$($ResourceFilter)"
			$i++
			$Folders.Folders
		} while ($Folders.Folders.count % 1000 -eq 0 -and $Folders.Folders.count -ne 0)
		
		
	
		return $AllFolders

	}
}
#EndRegion './Public/Get-HuduFolders.ps1' 38
#Region './Public/Get-HuduIntegrationMatchers.ps1' 0
function Get-HuduIntegrationMatchers {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [int]$IntegrationId,
        [switch]$Matched,
        [int]$SyncId = '',
        [string]$Identifier = '',
        [int]$CompanyId
    )
		
    $ResourceFilter = '&integration_id={0}' -f $IntegrationId

    if ($Matched) { $ResourceFilter = "$($ResourceFilter)&matched=true" }
    else { $ResourceFilter = "$($ResourceFilter)&matched=false" }

    if ($CompanyId) {
        $ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
    }
    if ($Identifier) {
        $ResourceFilter = "$($ResourceFilter)&identifier=$($Identifier)"
    }
    if ($SyncId) {
        $ResourceFilter = "$($ResourceFilter)&sync_id=$($SyncId)"
    }
		
    $i = 1;
    $AllMatchers = do {
        $Matchers = Invoke-HuduRequest -Method get -Resource "/api/v1/matchers?page=$i&page_size=1000$($ResourceFilter)"
        $i++
        $Matchers
    } while ($Matchers.matchers.count % 1000 -eq 0 -and $Matchers.matchers.count -ne 0)
				
    return $AllMatchers.matchers
}
#EndRegion './Public/Get-HuduIntegrationMatchers.ps1' 36
#Region './Public/Get-HuduMagicDashes.ps1' 0
function Get-HuduMagicDashes {
	Param (
		[Alias("company_id")]
		[Int]$CompanyId = '',
		[String]$Title = ''
	)
	$ResourceFilter = ''

	if ($CompanyId) {
		$ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
	}

	if ($Title) {
		$ResourceFilter = "$($ResourceFilter)&title=$($Title)"
	}
	
	$i = 1;
	$AllDashes = do {
		$Dashes = Invoke-HuduRequest -Method get -Resource "/api/v1/magic_dash?page=$i&page_size=1000$($ResourceFilter)"
		$i++
		$Dashes
	} while ($Dashes.count % 1000 -eq 0 -and $Dashes.count -ne 0)
		
	return $AllDashes
	
}
#EndRegion './Public/Get-HuduMagicDashes.ps1' 27
#Region './Public/Get-HuduObjectByUrl.ps1' 0
function Get-HuduObjectByUrl {
	[CmdletBinding()]
	Param (
		[uri]$Url
	)
	
	if ((Get-HuduBaseURL) -match $Url.Authority) {
		$null,$Type,$Slug = $Url.PathAndQuery -split '/'
		
		$SlugSplat = @{
			Slug = $Slug
		}

		switch ($Type) {
			'a' { # Asset
				Get-HuduAssets @SlugSplat
			}
			'admin' { # Admin path
				$null, $null, $Type, $Slug = $Url.PathAndQuery -split '/'
				$SlugSplat = @{
					Slug = $Slug
				}
				switch ($Type) {
					'asset_layouts' { # Asset layouts
						Get-HuduAssetLayouts @SlugSplat
					}
				}
			}
			'c' { # Company
				Get-HuduCompanies @SlugSplat
			}
			'kba' { # KB article
				Get-HuduArticles @SlugSplat
			}
			'passwords' { # Passwords
				Get-HuduPasswords @SlugSplat
			}
			'websites' { # Website
				Get-HuduWebsites @SlugSplat
			}
			default {
				Write-Error "Unsupported object type $Type"
			}
		}
	}
	else {
		Write-Error 'Provided URL does not match Hudu Base URL'
	}
}
 
#EndRegion './Public/Get-HuduObjectByUrl.ps1' 51
#Region './Public/Get-HuduPasswords.ps1' 0
function Get-HuduPasswords {
	[CmdletBinding()]
	Param (
		[Int]$Id = '',
		[Alias("company_id")]
		[Int]$CompanyId = '',
		[String]$Name = '',
		[String]$Slug
	)
	
	if ($Id) {
		$Password = Invoke-HuduRequest -Method get -Resource "/api/v1/asset_passwords/$id"
		return $Password
	} else {

		$ResourceFilter = ''

		if ($CompanyId) {
			$ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
		}

		if ($Name) {
			$ResourceFilter = "$($ResourceFilter)&name=$($Name)"
		}

		if ($Slug) {
			$ResourceFilter = "$($ResourceFilter)&slug=$($Slug)"
		}	
	
		$i = 1;
		$AllPasswords = do {
			$Passwords = Invoke-HuduRequest -Method get -Resource "/api/v1/asset_passwords?page=$i&page_size=1000$($ResourceFilter)"
			$i++
			$Passwords.asset_passwords
		} while ($Passwords.asset_passwords.count % 1000 -eq 0 -and $Passwords.asset_passwords.count -ne 0)
		
	
		return $AllPasswords
	
	}
}
#EndRegion './Public/Get-HuduPasswords.ps1' 42
#Region './Public/Get-HuduProcesses.ps1' 0
function Get-HuduProcesses {
	[CmdletBinding()]
	Param (
		[Int]$Id = '',
		[Alias("company_id")]
		[Int]$CompanyId = '',
		[String]$Name = '',
		[String]$Slug
	)
	
	if ($Id) {
		$Process = Invoke-HuduRequest -Method get -Resource "/api/v1/procedures/$id"
		return $Process
	} else {

		$ResourceFilter = ''

		if ($CompanyId) {
			$ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
		}

		if ($Name) {
			$ResourceFilter = "$($ResourceFilter)&name=$($Name)"
		}
	
		if ($Slug) {
			$ResourceFilter = "$($ResourceFilter)&slug=$($Slug)"
		}	

		$i = 1;
		$AllProcesses = do {
			$Processes = Invoke-HuduRequest -Method get -Resource "/api/v1/procedures?page=$i&page_size=1000$($ResourceFilter)"
			$i++
			$Processes.procedures
		} while ($Processes.procedures.count % 1000 -eq 0 -and $Processes.procedures.count -ne 0)
		
	
		return $AllProcesses
	
	}
}
#EndRegion './Public/Get-HuduProcesses.ps1' 42
#Region './Public/Get-HuduRelations.ps1' 0
function Get-HuduRelations {
	Param ()
	$ResourceFilter = ''

	if ($CompanyId) {
		$ResourceFilter = "$($ResourceFilter)&company_id=$($CompanyId)"
	}

	if ($Title) {
		$ResourceFilter = "$($ResourceFilter)&title=$($Title)"
	}
	
	$i = 1;
	$AllRelations = do {
		$Relations = Invoke-HuduRequest -Method get -Resource "/api/v1/relations?page=$i&page_size=1000$($ResourceFilter)"
		$i++
		$Relations.relations
	} while ($Relations.relations.count % 1000 -eq 0 -and $Relations.relations.count -ne 0)
		
	return $AllRelations
	
}
#EndRegion './Public/Get-HuduRelations.ps1' 23
#Region './Public/Get-HuduWebsites.ps1' 0
function Get-HuduWebsites {
	[CmdletBinding()]
	Param (
		[String]$Name = '',
		[Alias("website_id")]
		[String]$WebsiteId = '',
		[Int]$id = '',
		[String]$Slug
	)
	
	if ($WebsiteId) {
		$Website = Invoke-HuduRequest -Method get -Resource "/api/v1/websites/$($WebsiteId)"
		return $Website
	} else {
		
	
		$ResourceFilter = ''
	
		if ($Name) {
			$ResourceFilter = "&name=$($Name)"	
		}

		if ($Slug) {
			$ResourceFilter = "$($ResourceFilter)&slug=$($Slug)"
		}	
		
		$i = 1;
		$AllWebsites = do {
			$Websites = Invoke-HuduRequest -Method get -Resource "/api/v1/websites?page=$i&page_size=1000$($ResourceFilter)"
			$i++
			$Websites
		} while ($Websites.websites.count % 1000 -eq 0 -and $Websites.websites.count -ne 0)
		
			
		return $AllWebsites
		
	
	}
}
#EndRegion './Public/Get-HuduWebsites.ps1' 40
#Region './Public/Initialize-HuduFolder.ps1' 0
function Initialize-HuduFolder {
    [CmdletBinding()]
    param(
        [String[]]$FolderPath,
        [Alias("company_id")]
        [int]$CompanyId
    )

    if ($CompanyId) {
        $FolderMap = Get-HuduFolderMap -company_id $CompanyId
    } else {
        $FolderMap = Get-HuduFolderMap
    }

    $CurrentFolder = $Foldermap
    foreach ($Folder in $FolderPath) {
        if ($CurrentFolder.$(Get-HuduFolderCleanName $Folder)) {
            $CurrentFolder = $CurrentFolder.$(Get-HuduFolderCleanName $Folder)
        } else {
            $CurrentFolder = (New-HuduFolder -name $Folder -company_id $CompanyID -parent_folder_id $CurrentFolder.id).folder
        }
    }

    Return $CurrentFolder
}
#EndRegion './Public/Initialize-HuduFolder.ps1' 26
#Region './Public/New-HuduAPIKey.ps1' 0
function New-HuduAPIKey {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false,
			ValueFromPipeline = $true)]
		[String]
		$ApiKey
	)
		
	if ($ApiKey) {
		$SecApiKey = ConvertTo-SecureString $ApiKey -AsPlainText -Force
	} else {
		Write-Host "Please enter your Hudu API key, you can obtain it from https://your-hudu-domain/admin/api_keys:"
		$SecApiKey = Read-Host -AsSecureString
	}
	Set-Variable -Name "Int_HuduAPIKey" -Value $SecApiKey -Visibility Private -Scope script -Force

	if ($script:Int_HuduBaseURL) {
		[version]$version = (Get-HuduAppInfo).version
		if ($version -lt $script:HuduRequiredVersion) {
			Write-Host "A connection error occured or Hudu version is below $script:HuduRequiredVersion" -foregroundcolor yellow
		}
	}
}
#EndRegion './Public/New-HuduAPIKey.ps1' 25
#Region './Public/New-HuduArticle.ps1' 0
function New-HuduArticle {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[Parameter(Mandatory = $true)]
		[String]$Content,
		[Alias("folder_id")]
		[Int]$FolderId = '',
		[Alias("company_id")]
		[Int]$CompanyId = ''
	)
	

	$Article = [ordered]@{article = [ordered]@{} }
	
	$Article.article.add('name', $Name)
	$Article.article.add('content', $Content)
	
	if ($FolderId) {
		$Article.article.add('folder_id', $FolderId)
	}
	
	if ($CompanyId) {
		$Article.article.add('company_id', $CompanyId)
	}
	
	$JSON = $Article | convertto-json -Depth 10
	
	$Response = Invoke-HuduRequest -Method post -Resource "/api/v1/articles" -body $JSON
	
	$Response
	
}
#EndRegion './Public/New-HuduArticle.ps1' 35
#Region './Public/New-HuduAsset.ps1' 0
function New-HuduAsset {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[Alias("company_id")]
		[Parameter(Mandatory = $true)]
		[Int]$CompanyId,
		[Alias("asset_layout_id")]
		[Parameter(Mandatory = $true)]
		[Int]$AssetLayoutId,
		[Array]$Fields,
		[Alias("primary_serial")]
		[string]$PrimarySerial,
		[Alias("primary_mail")]
		[string]$PrimaryMail,
		[Alias("primary_model")]
		[string]$PrimaryModel,
		[Alias("primary_manufacturer")]
		[string]$PrimaryManufacturer
	)
	
	$Asset = [ordered]@{asset = [ordered]@{} }
	
	$Asset.asset.add('name', $Name)
	$Asset.asset.add('asset_layout_id', $AssetLayoutId)


	if ($PrimarySerial) {
		$Asset.asset.add('primary_serial', $PrimarySerial)
	}

	if ($PrimaryMail) {
		$Asset.asset.add('primary_mail', $PrimaryMail)
	}

	if ($PrimaryModel) {
		$Asset.asset.add('primary_model', $PrimaryModel)
	}

	if ($PrimaryManufacturer) {
		$Asset.asset.add('primary_manufacturer', $PrimaryManufacturer)
	}

	if ($Fields) {
		$Asset.asset.add('custom_fields', $Fields)
	}
	
	$JSON = $Asset | convertto-json -Depth 10
	
	$Response = Invoke-HuduRequest -Method post -Resource "/api/v1/companies/$CompanyId/assets" -body $JSON
	
	$Response
}
#EndRegion './Public/New-HuduAsset.ps1' 55
#Region './Public/New-HuduAssetLayout.ps1' 0
function New-HuduAssetLayout {
	[CmdletBinding()]
	# This will silence the warning for variables with Password in their name.
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[Parameter(Mandatory = $true)]
		[String]$Icon,
		[Parameter(Mandatory = $true)]
		[String]$Color,
		[Alias('icon_color')]
		[Parameter(Mandatory = $true)]
		[String]$IconColor,
		[Alias('include_passwords')]
		[bool]$IncludePasswords = '',
		[Alias('include_photos')]
		[bool]$IncludePhotos = '',
		[Alias('include_comments')]
		[bool]$IncludeComments = '',
		[Alias('include_files')]
		[bool]$IncludeFiles = '',
		[Alias('password_types')]
		[String]$PasswordTypes = '',
		[Parameter(Mandatory = $true)]
		[system.collections.generic.list[hashtable]]$Fields,
		[bool]$Active = $true
	)
	
	foreach ($field in $fields) {
		if ($field.show_in_list) { $field.show_in_list = [System.Convert]::ToBoolean($field.show_in_list) } else { $field.remove('show_in_list') }
		if ($field.required) { $field.required = [System.Convert]::ToBoolean($field.required) } else { $field.remove('required') }
		if ($field.expiration) { $field.expiration = [System.Convert]::ToBoolean($field.expiration) } else { $field.remove('expiration') }
	}

	$AssetLayout = [ordered]@{asset_layout = [ordered]@{} }
	
	$AssetLayout.asset_layout.add('name', $Name)
	$AssetLayout.asset_layout.add('icon', $Icon)
	$AssetLayout.asset_layout.add('color', $Color)
	$AssetLayout.asset_layout.add('icon_color', $IconColor)
	$AssetLayout.asset_layout.add('fields', $Fields)
	$AssetLayout.asset_layout.add('active', $Active)
		
	if ($IncludePasswords) {
		
		$AssetLayout.asset_layout.add('include_passwords', [System.Convert]::ToBoolean($IncludePasswords))
	}
	
	if ($IncludePhotos) {
		$AssetLayout.asset_layout.add('include_photos', [System.Convert]::ToBoolean($IncludePhotos))
	}
	
	if ($IncludeComments) {
		$AssetLayout.asset_layout.add('include_comments', [System.Convert]::ToBoolean($IncludeComments))
	}
	
	if ($IncludeFiles) {
		$AssetLayout.asset_layout.add('include_files', [System.Convert]::ToBoolean($IncludeFiles))
	}
	
	if ($PasswordTypes) {
		$AssetLayout.asset_layout.add('password_types', $PasswordTypes)
	}
	
	
	$JSON = $AssetLayout | ConvertTo-Json -Depth 10
	
	Write-Verbose $JSON
	
	$Response = Invoke-HuduRequest -Method post -Resource '/api/v1/asset_layouts' -Body $JSON
	
	$Response
}
#EndRegion './Public/New-HuduAssetLayout.ps1' 75
#Region './Public/New-HuduBaseURL.ps1' 0
function New-HuduBaseURL {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false,
			ValueFromPipeline = $true)]
		[String]
		$BaseURL
	)
		
	if (!$BaseURL) {
		Write-Host "Please enter your Hudu Base URL with no trailing /, for example https://demo.huducloud.com :"
		$BaseURL = Read-Host
	}
	Set-Variable -Name "Int_HuduBaseURL" -Value $BaseURL -Visibility Private -Scope script -Force

	if ($script:Int_HuduAPIKey) {
		[version]$Version = (Get-HuduAppInfo).version
		if ($Version -lt $script:HuduRequiredVersion) {
			Write-Host "A connection error occured or Hudu version is below $script:HuduRequiredVersion" -foregroundcolor yellow
		}
	}
}
#EndRegion './Public/New-HuduBaseURL.ps1' 23
#Region './Public/New-HuduCompany.ps1' 0
function New-HuduCompany {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [String]$Nickname = '',
	[Alias("company_type")]
	[String]$CompanyType = '',
        [Alias('address_line_1')]
        [String]$AddressLine1 = '',
        [Alias('address_line_2')]
        [String]$AddressLine2 = '',
        [String]$City = '',
        [String]$State = '',
        [Alias('PostalCode', 'PostCode')]
        [String]$Zip = '',
        [Alias('country_name')]
        [String]$CountryName = '',
        [Alias('phone_number')]
        [String]$PhoneNumber = '',
        [Alias('fax_number')]
        [String]$FaxNumber = '',
        [String]$Website = '',
        [Alias('id_number')]
        [String]$IdNumber = '',
        [String]$Notes = ''
    )
	

    $Company = [ordered]@{company = [ordered]@{} }
	
    $Company.company.add('name', $Name)
    if (-not ([string]::IsNullOrEmpty($Nickname))) { $Company.company.add('nickname', $Nickname) }
    if (-not ([string]::IsNullOrEmpty($Nickname))) { $Company.company.add('company_type', $CompanyType) }
    if (-not ([string]::IsNullOrEmpty($AddressLine1))) { $Company.company.add('address_line_1', $AddressLine1) }
    if (-not ([string]::IsNullOrEmpty($AddressLine2))) { $Company.company.add('address_line_2', $AddressLine2) }
    if (-not ([string]::IsNullOrEmpty($City))) { $Company.company.add('city', $City) }
    if (-not ([string]::IsNullOrEmpty($State))) { $Company.company.add('state', $State) }
    if (-not ([string]::IsNullOrEmpty($Zip))) { $Company.company.add('zip', $Zip) }
    if (-not ([string]::IsNullOrEmpty($CountryName))) { $Company.company.add('country_name', $CountryName) }
    if (-not ([string]::IsNullOrEmpty($PhoneNumber))) { $Company.company.add('phone_number', $PhoneNumber) }
    if (-not ([string]::IsNullOrEmpty($FaxNumber))) { $Company.company.add('fax_number', $FaxNumber) }
    if (-not ([string]::IsNullOrEmpty($Website))) { $Company.company.add('website', $Website) }
    if (-not ([string]::IsNullOrEmpty($IdNumber))) { $Company.company.add('id_number', $IdNumber) }
    if (-not ([string]::IsNullOrEmpty($Notes))) { $Company.company.add('notes', $Notes) }
 
    $JSON = $Company | ConvertTo-Json -Depth 10
    Write-Verbose $JSON
	
    $Response = Invoke-HuduRequest -Method post -Resource '/api/v1/companies' -Body $JSON
	
    $Response
	
}
#EndRegion './Public/New-HuduCompany.ps1' 55
#Region './Public/New-HuduFolder.ps1' 0
function New-HuduFolder {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[String]$Icon = '',
		[String]$Description = '',
		[Alias("parent_folder_id")]
		[Int]$ParentFolderId = '',
		[Alias("company_id")]
		[Int]$CompanyId = ''
	)
	
	$Folder = [ordered]@{folder = [ordered]@{} }
	
	$Folder.folder.add('name', $Name)
		
	if ($Icon) {
		$Folder.folder.add('icon', $Icon)
	}
	
	if ($Description) {
		$Folder.folder.add('description', $Description)
	}
	
	if ($ParentFolderId) {
		$Folder.folder.add('parent_folder_id', $ParentFolderId)
	}
	
	if ($CompanyId) {
		$Folder.folder.add('company_id', $CompanyId)
	}
		
	$JSON = $Folder | convertto-json
	
	$Response = Invoke-HuduRequest -Method post -Resource "/api/v1/folders" -body $JSON
	
	$Response
	
}
#EndRegion './Public/New-HuduFolder.ps1' 41
#Region './Public/New-HuduPassword.ps1' 0
function New-HuduPassword {
  [CmdletBinding()]
  # This will silence the warning for variables with Password in their name.
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
  Param (
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Alias("company_id")]
    [Parameter(Mandatory = $true)]
    [Int]$CompanyId,
    [Alias("passwordable_type")]
    [String]$PasswordableType = '',
    [Alias("passwordable_id")]
    [int]$PasswordableId = '',
    [Alias("in_portal")]
    [Bool]$InPortal = $false,
    [Parameter(Mandatory = $true)]
    [String]$Password = '',
    [Alias("otp_secret")]
    [string]$OTPSecret = '',
    [String]$URL = '',
    [String]$Username = '',
    [String]$Description = '',
    [Alias("password_type")]
    [String]$PasswordType = ''
  )
  
  $AssetPassword = [ordered]@{asset_password = [ordered]@{} }
      
  $AssetPassword.asset_password.add('name', $Name)
  $AssetPassword.asset_password.add('company_id', $CompanyId)
  $AssetPassword.asset_password.add('password', $Password)
  $AssetPassword.asset_password.add('in_portal', $InPortal)

  if ($PasswordableType) {
    $AssetPassword.asset_password.add('passwordable_type', $PasswordableType)
  }
  if ($PasswordableId) {
    $AssetPassword.asset_password.add('passwordable_id', $PasswordableId)
  }
 
  if ($OTPSecret) {
    $AssetPassword.asset_password.add('otp_secret', $OTPSecret)
  }

  if ($URL) {
    $AssetPassword.asset_password.add('url', $URL)
  }

  if ($Username) {
    $AssetPassword.asset_password.add('username', $Username)
  }

  if ($Description) {
    $AssetPassword.asset_password.add('description', $Description)
  }

  if ($PasswordType) {
    $AssetPassword.asset_password.add('password_type', $PasswordType)
  }
  
  $JSON = $AssetPassword | ConvertTo-Json -Depth 10
  
  $Response = Invoke-HuduRequest -Method post -Resource "/api/v1/asset_passwords" -body $JSON
  
  $Response

}
#EndRegion './Public/New-HuduPassword.ps1' 69
#Region './Public/New-HuduRelation.ps1' 0
function New-HuduRelation {
	[CmdletBinding()]
	Param (
		[String]$Description,
		[Parameter(Mandatory = $true)]
		[ValidateSet('Asset','Website','Procedure','AssetPassword','Company','Article')]
		[Alias("fromable_type")]
		[String]$FromableType,
		[Alias("fromable_id")]
		[int]$FromableID,
		[Alias("toable_type")]
		[String]$ToableType,
		[Alias("toable_id")]
		[int]$ToableID,
		[Alias("is_inverse")]
		[string]$ISInverse
	)
	

	$Relation = [ordered]@{relation = [ordered]@{} }
	
	$Relation.relation.add('fromable_type', $FromableType)
	$Relation.relation.add('fromable_id', $FromableID)
	$Relation.relation.add('toable_type', $ToableType)
	$Relation.relation.add('toable_id', $ToableID)
	
	if ($Description) {
		$Relation.relation.add('description', $Description)
	}
	
	if ($ISInverse) {
		$Relation.relation.add('is_inverse', $ISInverse)
	}
	
	$JSON = $Relation | convertto-json -Depth 100
	
	$Response = Invoke-HuduRequest -Method post -Resource "/api/v1/relations" -body $JSON
	
	$Response
	
}
#EndRegion './Public/New-HuduRelation.ps1' 42
#Region './Public/New-HuduWebsite.ps1' 0
function New-HuduWebsite {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[String]$Notes = '',
		[String]$Paused = '',
		[Alias("company_id")]
		[Parameter(Mandatory = $true)]
		[Int]$CompanyId,
		[Alias("disable_dns")]
		[String]$DisableDNS = '',
		[Alias("disable_ssl")]
		[String]$DisableSSL = '',
		[Alias("disable_whois")]
		[String]$DisableWhois = ''
	)
	
	$Website = [ordered]@{website = [ordered]@{} }
	
	$Website.website.add('name', $Name)
		
	if ($Notes) {
		$Website.website.add('notes', $Notes)
	}
	
	if ($Paused) {
		$Website.website.add('paused', $Paused)
	}
	
	$Website.website.add('company_id', $CompanyId)
	
	if ($DisableDNS) {
		$Website.website.add('disable_dns', $DisableDNS)
	}
	
	if ($DisableSSL) {
		$Website.website.add('disable_ssl', $DisableSSL)
	}
	
	if ($DisableWhois) {
		$Website.website.add('disable_whois', $DisableWhois)
	}
	
	$JSON = $Website | ConvertTo-Json
	
	$Response = Invoke-HuduRequest -Method post -Resource "/api/v1/websites" -body $JSON
	
	$Response
	
}
#EndRegion './Public/New-HuduWebsite.ps1' 52
#Region './Public/Remove-HuduAPIKey.ps1' 0
function Remove-HuduAPIKey {
	[CmdletBinding()]
	Param()
	Set-Variable -Name "Int_HuduAPIKey" -Value $null -Visibility Private -Scope script -Force
}
#EndRegion './Public/Remove-HuduAPIKey.ps1' 6
#Region './Public/Remove-HuduArticle.ps1' 0
function Remove-HuduArticle {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id
  )
      
  $Response = Invoke-HuduRequest -Method delete -Resource "/api/v1/articles/$Id"
    
  $Response
    
}
#EndRegion './Public/Remove-HuduArticle.ps1' 13
#Region './Public/Remove-HuduAsset.ps1' 0
function Remove-HuduAsset {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id,
    [Alias("company_id")]
    [Parameter(Mandatory = $true)]
    [Int]$CompanyId
  )
      
  $Response = Invoke-HuduRequest -Method delete -Resource "/api/v1/companies/$CompanyId/assets/$Id"
    
  $Response
    
}
#EndRegion './Public/Remove-HuduAsset.ps1' 16
#Region './Public/Remove-HuduBaseURL.ps1' 0
function Remove-HuduBaseURL {
	[CmdletBinding()]
	Param()
	Set-Variable -Name "Int_HuduBaseURL" -Value $null -Visibility Private -Scope script -Force
}
#EndRegion './Public/Remove-HuduBaseURL.ps1' 6
#Region './Public/Remove-HuduMagicDash.ps1' 0
function Remove-HuduMagicDash {
	[CmdletBinding()]
	Param (
		[String]$Title = '',
		[Alias("company_name")]
		[String]$CompanyName = '',
		[String]$Id = ''
	)
	
	if ($id) {
		$null = Invoke-HuduRequest -Method delete -Resource "/api/v1/magic_dash/$Id"
	
	} else {

		if ($Title -and $CompanyName) {
	
			$MagicDash = @{}
	
			$MagicDash.add('title', $Title)
			$MagicDash.add('company_name', $CompanyName)
				
			$JSON = $MagicDash | convertto-json
	
			$null = Invoke-HuduRequest -Method delete -Resource "/api/v1/magic_dash" -body $JSON
	
		} else {
			Write-Host "ERROR: Please set title and company_name" -ForegroundColor Red
		}
	
	}
}
#EndRegion './Public/Remove-HuduMagicDash.ps1' 32
#Region './Public/Remove-HuduPassword.ps1' 0
function Remove-HuduPassword {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id
  )
    
  $Response = Invoke-HuduRequest -Method delete -Resource "/api/v1/asset_passwords/$Id"
  
  $Response
  
}
#EndRegion './Public/Remove-HuduPassword.ps1' 13
#Region './Public/Remove-HuduRelation.ps1' 0
function Remove-HuduRelation {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id
  )
      
  $Response = Invoke-HuduRequest -Method delete -Resource "/api/v1/relations/$Id"
    
  $Response
    
}
#EndRegion './Public/Remove-HuduRelation.ps1' 13
#Region './Public/Remove-HuduWebsite.ps1' 0
function Remove-HuduWebsite {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id
  )
      
  $Response = Invoke-HuduRequest -Method delete -Resource "/api/v1/websites/$Id"
    
  $Response
    
}
#EndRegion './Public/Remove-HuduWebsite.ps1' 13
#Region './Public/Set-HuduArticle.ps1' 0
function Set-HuduArticle {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[Parameter(Mandatory = $true)]
		[String]$Content,
		[Alias("folder_id")]
		[Int]$FolderId = '',
		[Alias("company_id")]
		[Int]$CompanyId = '',
		[Alias("article_id", "id")]
		[Parameter(Mandatory = $true)]
		[Int]$ArticleId
	)

	$Article = [ordered]@{article = [ordered]@{} }
	
	$Article.article.add('name', $Name)
	$Article.article.add('content', $Content)
	
	if ($FolderId) {
		$Article.article.add('folder_id', $FolderId)
	}
	
	if ($CompanyId) {
		$Article.article.add('company_id', $CompanyId)
	}
	
	$JSON = $Article | ConvertTo-Json -Depth 10
	
	$Response = Invoke-HuduRequest -Method put -Resource "/api/v1/articles/$ArticleId" -body $JSON
	
	$Response
	
}
#EndRegion './Public/Set-HuduArticle.ps1' 37
#Region './Public/Set-HuduArticleArchive.ps1' 0
function Set-HuduArticleArchive {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id,
    [Parameter(Mandatory = $true)]
    [Bool]$Archive
  )
    
  if ($Archive) {
    $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/articles/$Id/archive"
  } else {
    $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/articles/$Id/unarchive"
  }
  $Response
}
#EndRegion './Public/Set-HuduArticleArchive.ps1' 17
#Region './Public/Set-HuduAsset.ps1' 0
function Set-HuduAsset {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[Alias("company_id")]
		[Parameter(Mandatory = $true)]
		[Int]$CompanyId,
		[Alias("asset_layout_id")]
		[Parameter(Mandatory = $true)]
		[Int]$AssetLayoutId,
		[Array]$Fields,
		[Alias("asset_id")]
		[Parameter(Mandatory = $true)]
		[Int]$AssetId,
		[Alias("primary_serial")]
		[string]$PrimarySerial,
		[Alias("primary_mail")]
		[string]$PrimaryMail,
		[Alias("primary_model")]
		[string]$PrimaryModel,
		[Alias("primary_manufacturer")]
		[string]$PrimaryManufacturer
	)
	
	$Asset = [ordered]@{asset = [ordered]@{} }
	
	$Asset.asset.add('name', $Name)
	$Asset.asset.add('asset_layout_id', $AssetLayoutId)

	if ($PrimarySerial) {
		$Asset.asset.add('primary_serial', $PrimarySerial)
	}

	if ($PrimaryMail) {
		$Asset.asset.add('primary_mail', $PrimaryMail)
	}

	if ($PrimaryModel) {
		$Asset.asset.add('primary_model', $PrimaryModel)
	}

	if ($PrimaryManufacturer) {
		$Asset.asset.add('primary_manufacturer', $PrimaryManufacturer)
	}

	if ($Fields) {
		$Asset.asset.add('custom_fields', $Fields)
	}
	
	$JSON = $Asset | ConvertTo-Json -Depth 10
	
	$Response = Invoke-HuduRequest -Method put -Resource "/api/v1/companies/$CompanyId/assets/$AssetId" -body $JSON
	
	$Response
	
}
#EndRegion './Public/Set-HuduAsset.ps1' 58
#Region './Public/Set-HuduAssetArchive.ps1' 0
function Set-HuduAssetArchive {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id,
    [Alias("company_id")]
    [Parameter(Mandatory = $true)]
    [Int]$CompanyId,
    [Parameter(Mandatory = $true)]
    [Bool]$Archive
  )
    
  if ($Archive) {
    $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/companies/$CompanyId/assets/$Id/archive"
  } else {
    $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/companies/$CompanyId/assets/$Id/unarchive"
  }
  $Response
}
#EndRegion './Public/Set-HuduAssetArchive.ps1' 20
#Region './Public/Set-HuduAssetLayout.ps1' 0
function Set-HuduAssetLayout {
	[CmdletBinding()]
	# This will silence the warning for variables with Password in their name.
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
	Param (
		[Parameter(Mandatory = $true)]
		[Int]$Id,
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[Parameter(Mandatory = $true)]
		[String]$Icon,
		[Parameter(Mandatory = $true)]
		[String]$Color,
		[Alias("icon_color")]
		[Parameter(Mandatory = $true)]
		[String]$IconColor,
		[Alias("include_passwords")]
		[bool]$IncludePasswords = '',
		[Alias("include_photos")]
		[bool]$IncludePhotos = '',
		[Alias("include_comments")]
		[bool]$IncludeComments = '',
		[Alias("include_files")]
		[bool]$IncludeFiles = '',
		[Alias("password_types")]
		[String]$PasswordTypes = '',
		[Parameter(Mandatory = $true)]
		[array]$Fields,
		[bool]$Active = $true
	)
	
	foreach ($Field in $Fields) {
		$Field.show_in_list = [System.Convert]::ToBoolean($Field.show_in_list)
		$Field.required = [System.Convert]::ToBoolean($Field.required)
		$Field.expiration = [System.Convert]::ToBoolean($Field.expiration)
	}


	$AssetLayout = [ordered]@{asset_layout = [ordered]@{} }
	
	$AssetLayout.asset_layout.add('name', $Name)
	$AssetLayout.asset_layout.add('icon', $Icon)
	$AssetLayout.asset_layout.add('color', $Color)
	$AssetLayout.asset_layout.add('icon_color', $IconColor)
	$AssetLayout.asset_layout.add('fields', $Fields)
	$AssetLayout.asset_layout.add('active', $Active)
		
	if ($IncludePasswords) {
		$AssetLayout.asset_layout.add('include_passwords', [System.Convert]::ToBoolean($IncludePasswords))
	}
	
	if ($IncludePhotos) {
		$AssetLayout.asset_layout.add('include_photos', [System.Convert]::ToBoolean($IncludePhotos))
	}
	
	if ($IncludeComments) {
		$AssetLayout.asset_layout.add('include_comments', [System.Convert]::ToBoolean($IncludeComments))
	}
	
	if ($IncludeFiles) {
		$AssetLayout.asset_layout.add('include_files', [System.Convert]::ToBoolean($IncludeFiles))
	}
	
	if ($PasswordTypes) {
		$AssetLayout.asset_layout.add('password_types', $PasswordTypes)
	}
	
	
	$JSON = $AssetLayout | convertto-json -Depth 10
	
	$Response = Invoke-HuduRequest -Method put -Resource "/api/v1/asset_layouts/$Id" -body $JSON
	
	$Response
}
#EndRegion './Public/Set-HuduAssetLayout.ps1' 75
#Region './Public/Set-HuduCompany.ps1' 0
function Set-HuduCompany {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [Int]$Id,
        [Parameter(Mandatory = $true)]
        [String]$Name,
        [String]$Nickname = '',
	[Alias("company_type")]
	[String]$CompanyType = '',
        [Alias("address_line_1")]
        [String]$AddressLine1 = '',
        [Alias("address_line_2")]
        [String]$AddressLine2 = '',
        [String]$City = '',
        [String]$State = '',
        [Alias("PostalCode", "PostCode")]
        [String]$Zip = '',
        [Alias("country_name")]
        [String]$CountryName = '',
        [Alias("phone_number")]
        [String]$PhoneNumber = '',
        [Alias("fax_number")]
        [String]$FaxNumber = '',
        [String]$Website = '',
        [Alias("id_number")]
        [String]$IdNumber = '',
	[Alias("parent_company_id")]
	[Int]$ParentCompanyId,
        [String]$Notes = ''
    )
	

    $Company = [ordered]@{company = [ordered]@{} }
	
    $Company.company.add('name', $Name)
    $Company.company.add('nickname', $Nickname)
    $Company.company.add('company_type', $CompanyType)
    $Company.company.add('address_line_1', $AddressLine1)
    $Company.company.add('address_line_2', $AddressLine2)
    $Company.company.add('city', $City)
    $Company.company.add('state', $State)
    $Company.company.add('zip', $Zip)
    $Company.company.add('country_name', $CountryName)
    $Company.company.add('phone_number', $PhoneNumber)
    $Company.company.add('fax_number', $FaxNumber)
    $Company.company.add('website', $Website)
    $Company.company.add('id_number', $IdNumber)
    $Company.company.add('parent_company_id', $ParentCompanyId)
    $Company.company.add('notes', $Notes)
	
    $JSON = $Company | ConvertTo-Json -Depth 10
	
    $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/companies/$Id" -body $JSON
	
    $Response
}
#EndRegion './Public/Set-HuduCompany.ps1' 58
#Region './Public/Set-HuduCompanyArchive.ps1' 0
function Set-HuduCompanyArchive {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [Int]$Id,
        [Parameter(Mandatory = $true)]
        [Bool]$Archive
    )
    
    if ($Archive -eq $true) {
        $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/companies/$Id/archive"
    } else {
        $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/companies/$Id/unarchive"
    }
    $Response
}
#EndRegion './Public/Set-HuduCompanyArchive.ps1' 17
#Region './Public/Set-HuduFolder.ps1' 0
function Set-HuduFolder {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[Int]$Id,
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[String]$Icon = '',
		[String]$Description = '',
		[Alias("parent_folder_id")]
		[Int]$ParentFolderId = '',
		[Alias("company_id")]
		[Int]$CompanyId = ''
	)
	
	$Folder = [ordered]@{folder = [ordered]@{} }
	
	$Folder.folder.add('name', $Name)
		
	if ($icon) {
		$Folder.folder.add('icon', $Icon)
	}
	
	if ($Description) {
		$Folder.folder.add('description', $Description)
	}
	
	if ($ParentFolderId) {
		$Folder.folder.add('parent_folder_id', $ParentFolderId)
	}
	
	if ($CompanyId) {
		$Folder.folder.add('company_id', $CompanyId)
	}
		
	$JSON = $Folder | convertto-json
	
	$Response = Invoke-HuduRequest -Method put -Resource "/api/v1/folders/$Id" -body $JSON
	
	$Response
}
#EndRegion './Public/Set-HuduFolder.ps1' 42
#Region './Public/Set-HuduIntegrationMatcher.ps1' 0
function Set-HuduIntegrationMatcher {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Id,

        [Parameter(ParameterSetName = 'AcceptSuggestedMatch')]
        [switch]$AcceptSuggestedMatch,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SetCompanyId')]
        [Alias('company_id')]
        [String]$CompanyId,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('potential_company_id')]
        [String]$PotentialCompanyId,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('sync_id')]
        [String]$SyncId,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [String]$Identifier
    )

    Process {
        $Matcher = [ordered]@{matcher = [ordered]@{} }
	
        if ($AcceptSuggestedMatch) {
            $Matcher.matcher.add('company_id', $PotentialCompanyId) | Out-Null
        }
        else {
            $Matcher.matcher.add('company_id', $CompanyId) | Out-Null
        }

        if ($PotentialCompanyId) {
            $Matcher.matcher.add('potential_company_id', $PotentialCompanyId) | Out-Null
        }
        if ($SyncId) {
            $Matcher.matcher.add('sync_id', $SyncId) | Out-Null
        }
        if ($Identifier) {
            $Matcher.matcher.add('identifier', $identifier) | Out-Null
        }
	
        $JSON = $Matcher | ConvertTo-Json -Depth 10
	
        $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/matchers/$Id" -Body $JSON
        $Response
    }
}
#EndRegion './Public/Set-HuduIntegrationMatcher.ps1' 52
#Region './Public/Set-HuduMagicDash.ps1' 0
function Set-HuduMagicDash {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[String]$Title,
		[Alias("company_name")]
		[Parameter(Mandatory = $true)]
		[String]$CompanyName,
		[Parameter(Mandatory = $true)]
		[String]$Message,
		[String]$Icon = '',
		[Alias("image_url")]
		[String]$ImageURL = '',
		[Alias("content_link")]
		[String]$ContentLink = '',
		[String]$Content = '',
		[String]$Shade = ''
	)
	
	if ($Icon -and $ImageURL) {
		write-error ("You can only use one of icon or image URL")
		exit 1
	}
	
	if ($content_link -and $content) {
		write-error ("You can only use one of content or content_link")
		exit 1
	}
	
	$MagicDash = [ordered]@{}
	
	if ($Title) {
		$MagicDash.add('title', $Title)
	}
	
	if ($CompanyName) {
		$MagicDash.add('company_name', $CompanyName)
	}
	
	if ($Message) {
		$MagicDash.add('message', $Message)
	}
	
	if ($Icon) {
		$MagicDash.add('icon', $Icon)
	}
	
	if ($ImageURL) {
		$MagicDash.add('image_url', $ImageURL)
	}
	
	if ($ContentLink) {
		$MagicDash.add('content_link', $ContentLink)
	}
	
	if ($Content) {
		$MagicDash.add('content', $Content)
	}
	
	if ($Shade) {
		$MagicDash.add('shade', $Shade)
	}
	
	$JSON = $MagicDash | convertto-json
	
	$Response = Invoke-HuduRequest -Method post -Resource "/api/v1/magic_dash" -body $JSON
	
	$Response
}
#EndRegion './Public/Set-HuduMagicDash.ps1' 70
#Region './Public/Set-HuduPassword.ps1' 0
function Set-HuduPassword {
  [CmdletBinding()]
  # This will silence the warning for variables with Password in their name.
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
  Param (
    [Parameter(Mandatory = $true)] 
    [Int]$Id,
    [Parameter(Mandatory = $true)]
    [String]$Name,
    [Alias("company_id")]
    [Parameter(Mandatory = $true)]
    [Int]$CompanyId,
    [Alias("passwordable_type")]
    [String]$PasswordableType = '',
    [Alias("passwordable_id")]
    [int]$PasswordableId = '',
    [Alias("in_portal")]
    [Bool]$InPortal = $false,
    [Parameter(Mandatory = $true)]
    [String]$Password = '',
    [Alias("otp_secret")]
    [string]$OTPSecret = '',
    [String]$URL = '',
    [String]$Username = '',
    [String]$Description = '',
    [Alias("password_type")]
    [String]$PasswordType = ''
  )
  

  $AssetPassword = [ordered]@{asset_password = [ordered]@{} }
  
  $AssetPassword.asset_password.add('name', $Name)
  $AssetPassword.asset_password.add('company_id', $CompanyId)
  $AssetPassword.asset_password.add('password', $Password)
  $AssetPassword.asset_password.add('in_portal', $InPortal)

  if ($PasswordableType) {
    $AssetPassword.asset_password.add('passwordable_type', $PasswordableType)
  }
  if ($PasswordableId) {
    $AssetPassword.asset_password.add('passwordable_id', $PasswordableId)
  }
 
  if ($OTPSecret) {
    $AssetPassword.asset_password.add('otp_secret', $OTPSecret)
  }

  if ($URL) {
    $AssetPassword.asset_password.add('url', $URL)
  }

  if ($Username) {
    $AssetPassword.asset_password.add('username', $Username)
  }

  if ($Description) {
    $AssetPassword.asset_password.add('description', $Description)
  }

  if ($PasswordType) {
    $AssetPassword.asset_password.add('password_type', $PasswordType)
  }
  
  $JSON = $AssetPassword | convertto-json -Depth 10
  
  $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/asset_passwords/$Id" -body $JSON
  
  $Response
}
#EndRegion './Public/Set-HuduPassword.ps1' 71
#Region './Public/Set-HuduPasswordArchive.ps1' 0
function Set-HuduPasswordArchive {
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory = $true)]
    [Int]$Id,
    [Parameter(Mandatory = $true)]
    [Bool]$Archive
  )
    
  if ($Archive) {
    $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/asset_passwords/$Id/archive"
  } else {
    $Response = Invoke-HuduRequest -Method put -Resource "/api/v1/asset_passwords/$Id/unarchive"
  }
  $Response
}
#EndRegion './Public/Set-HuduPasswordArchive.ps1' 17
#Region './Public/Set-HuduWebsite.ps1' 0
function Set-HuduWebsite {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[Int]$Id,
		[Parameter(Mandatory = $true)]
		[String]$Name,
		[String]$Notes = '',
		[String]$Paused = '',
		[Alias("company_id")]
		[Parameter(Mandatory = $true)]
		[Int]$CompanyId,
		[Alias("disable_dns")]
		[String]$DisableDNS = '',
		[Alias("disable_ssl")]
		[String]$DisableSSL = '',
		[Alias("disable_whois")]
		[String]$DisableWhois = ''
	)
	
	$Website = [ordered]@{website = [ordered]@{} }
	
	$Website.website.add('name', $Name)
		
	if ($Notes) {
		$Website.website.add('notes', $Notes)
	}
	
	if ($Paused) {
		$Website.website.add('paused', $Paused)
	}
	
	$Website.website.add('company_id', $companyid)
	
	if ($DisableDNS) {
		$Website.website.add('disable_dns', $DisableDNS)
	}
	
	if ($DisableSSL) {
		$Website.website.add('disable_ssl', $DisableSSL)
	}
	
	if ($DisableWhois) {
		$Website.website.add('disable_whois', $DisableWhois)
	}
	
	$JSON = $Website | convertto-json
	
	$Response = Invoke-HuduRequest -Method put -Resource "/api/v1/websites/$Id" -body $JSON
	
	$Response
	
}
#EndRegion './Public/Set-HuduWebsite.ps1' 54
