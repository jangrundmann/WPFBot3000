
Using Namespace System.Windows.Controls
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms


function Merge-HashTable {
    [CmdletBinding()]
    Param([Hashtable]$Base,
        [Hashtable]$Extension)

    $out = $Base.Clone()
    foreach ($item in $Extension.GetEnumerator()) {
        $out[$item.Key] = $item.Value
    }
    $out
}

Function FindChild{
    Param($parent, $childName)


  if ($parent -eq $null) {return $null}

  $foundChild =$null;

  $childrenCount = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($parent)
  if($childrenCount -eq 0) {break}
  foreach ($i in 0..($childrenCount-1))
  {
    $child = [System.Windows.Media.VisualTreeHelper]::GetChild($parent, $i)
    if($child.Name -ne $childName) {
      $foundChild = FindChild $child  $childName

      if ($foundChild -ne $null) {break}
    } else {
       $foundChild = $child
      break
    }

  }
  return $foundChild

}

function Window {
  param([scriptblock]$Contents,
    [hashtable]$labelMap=@{},
  [hashtable[]]$Events,
  [switch]$nolabels)
  $w = new-object system.windows.window -Property @{
    SizeToContent = 'WidthAndHeight'
    Margin        = New-object System.Windows.Thickness 10
  }
  [System.Windows.UIElement[]]$c = & $Contents
  $border = new-object Border -property @{Padding = 10;VerticalAlignment='Stretch';HorizontalAlignment='Stretch' }
  #$w.Content = $border
  $grid = new-object Grid -Property @{
    VerticalAlignment='Stretch';HorizontalAlignment='Stretch';Margin=5
    ShowGridLines=$true
  }
  1..$C.Count | ForEach-Object { $grid.RowDefinitions.Add( (new-object RowDefinition -Property @{Height='Auto'}))}
  if(-not $nolabels) {$grid.ColumnDefinitions.Add((new-object ColumnDefinition -property @{Width='Auto';Name='Labels'}))}
  $grid.ColumnDefinitions.Add((new-object ColumnDefinition -property @{Width='Auto';Name='Controls'}))
  $border.Child = $grid
  $grid.RowDefinitions.RemoveAt(0);
  $Row = 0
  foreach ($control in $c) {
    if(-not ($control -is [CheckBox]) -and
      (-not ($control -is [Label]))
    ){
      $controlColumn=0
      if(-not $nolabels){
          $labelText=$Control.Name
          if($labelMap.ContainsKey($control.Name)){
            $labelText=$labelMap[$control.Name]
          }
          $l = Label $labelText -property {Width='Auto' }
          [Grid]::SetRow($l, $row)
          [Grid]::SetColumn($l, 0)
          $grid.Children.Add($l) | out-null
          $controlColumn=1
      }
    }
    [Grid]::SetRow($control, $row)
    [Grid]::SetColumn($control, $controlColumn)
    $grid.Children.Add($control) | out-null
    $row += 1
  }
  $w| add-Member -MemberType ScriptMethod -Name GetControlByName -Value {Param($name) FindChild -parent $w -childName $name}
  foreach($item in $events){
    $control=$w.GetControlByName($item.Name)
    if($control){
      $control."Add_$($item.EventName)"($item.Action)
    }
  }
  $w.Content=$border
  $w.Width = $grid.width
  $w.UpdateLayout()
  $w

}

function Dialog {
    param([scriptblock]$Contents,
    [hashtable]$labelMap=@{},
  [hashtable[]]$Events,
  [switch]$nolabels)
    $c=& $contents
    $PSBoundParameters.Remove('Contents')
    $w=Window {
                $c
                StackPanel {Button OK {  $this.Window.DialogResult=$true } -property @{}
                            Button Cancel { $this.Window.DialogResult=$false} -property @{}
                            }  -Orientation Horizontal -Property @{Height=20}
                } @PSBoundParameters
    $output = @{}
    $dialogResult = $w.Showdialog()
    if ($dialogResult) {
        $c | ForEach-Object { if($_ | get-member GetControlValue -and $_.Name -ne ''){      $output.Add($_.Name, $_.GetControlValue()) }}
        [pscustomobject]$output
    }
}

function LabeledControl {
    Param($ctrl, $text)
    $stack = new-object StackPanel -Property @{
        Name        = $text
        Orientation = [Orientation]::Horizontal
    }
    $stack.Children.Add((Label $text)) | out-null
    $stack.Children.Add($o) | out-null
    $stack | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.Children[1].GetControlValue()} -PassThru

}
function TextBox {
    Param($Name, $InitialValue = "", $property = @{})
    $baseProperties = @{
        Name = $name
        Text = $InitialValue
    }
    $properties = Merge-HashTable $baseProperties $property
    $o = new-object TextBox -Property $properties
    $o | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $o | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.Text} -PassThru
}


function MultiLineTextBox {
    Param($Name, $InitialValue = "", $property = @{})
    $baseProperties = @{
        Name = $name
        Text = $InitialValue
        TextWrapping="Wrap"
        AcceptsReturn="True"
        VerticalScrollBarVisibility="Visible"
    }
    $properties = Merge-HashTable $baseProperties $property
    $o = new-object TextBox -Property $properties
    $o | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $o | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.Text} -PassThru
}


function Password {
    Param($Name, [SecureString]$InitialValue, $property = @{})
    $baseProperties = @{
        Name     = $name
        SecurePassword = $InitialValue
    }
    $properties = Merge-HashTable $baseProperties $property
    $o = new-object PasswordBox -Property $properties
    $o | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $o | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.SecurePassword} -PassThru
}

function Label {
    Param($Text, $name)
    $label=new-object Label -Property @{
        Content = $text
    }
    if($name){
        $label.Name=$name
    }
    $label
}

Function FilePicker {
    Param($Name, $InitialValue)

    $stack = new-object StackPanel -Property @{
        Name        = $name
        Orientation = [Orientation]::Horizontal
    }
    $t = TextBox -Name "Temp_$name" -InitialValue $InitialValue -property @{IsReadOnly = $true}
    $stack.Children.Add($t) | out-null
    $btn = new-object Button -Property @{
        Content = 'Browse'
        Tag     = $t
    }
    $btn.Add_Click( {
            PAram($sender, $e)
            $ofd = new-object Microsoft.Win32.OpenFileDialog
            $txt = [TextBox]$sender.Tag
            if ($txt.Text) {
                $ofd.InitialDirectory = [system.io.path]::GetDirectoryName($txt.Text)
                $ofd.FileName = [system.io.path]::GetFileName($txt.Text)
            }
            if ($ofd.ShowDialog()) {
                $txt.Text = $ofd.FileName
            }
        })
    $stack.Children.Add($btn) | out-null
    $stack | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $stack | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.Children[0].GetControlValue()} -PassThru

}

Function DirectoryPicker {
    Param($Name, $InitialValue)

    $stack = new-object StackPanel -Property @{
        Name        = $name
        Orientation = [Orientation]::Horizontal
    }
    $t = TextBox -Name "Temp_$name" -InitialValue $InitialValue -property @{IsReadOnly = $true}
    $stack.Children.Add($t) | out-null
    $btn = new-object Button -Property @{
        Content = 'Browse'
        Tag     = $t
    }
    $btn.Add_Click( {
            PAram($sender, $e)
            $ofd = new-object System.Windows.Forms.FolderBrowserDialog
            $txt = [TextBox]$sender.Tag
            if ($txt.Text) {
                $ofd.SelectedPath = $txt.Text
            }
            if ($ofd.ShowDialog()) {
                $txt.Text = $ofd.SelectedPath
            }
        })
    $stack.Children.Add($btn) | out-null
    $stack | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.Children[0].GetControlValue()} -PassThru

}

Function CredentialPicker {
    Param($Name, [PSCredential]$InitialValue)

    $stack = new-object StackPanel -Property @{
        Name        = $name
        Orientation = [Orientation]::Horizontal
    }

    $t = TextBox -Name "Temp_$name" -property @{IsReadOnly = $true}
    if($InitialValue){
        $t.tag=$InitialValue
        $t.text=$initialvalue.GetNetworkCredential().UserName
    } else {
        $t.tag=$null
        $t.text='<none>'
    }
    $stack.Children.Add($t) | out-null
    $btn = new-object Button -Property @{
        Content = 'Edit'
        Tag     = $t
    }
    $btn.Add_Click( {
            Param($sender, $e)
            $txt = [TextBox]$sender.Tag

           $cred=CredentialDialog $txt.tag
           $txt.Tag=$cred
           $txt.Text=$cred.GetNetworkCredential().Username
        })
    $stack.Children.Add($btn) | out-null
    $stack | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.Children[0].Tag} -PassThru

}
function ListBox {
    Param($name, $contents=@(), $initialValue, $property = @{})
    $baseProperties = @{
        Name = $name
    }
    $properties = Merge-HashTable $baseProperties $property

    $l = new-object ListBox -Property $properties
    if($Contents){
    $contents | ForEach-Object {
                $lvi=new-object ListBoxItem
                $lvi.Tag=$_
                $lvi.Content=$_.ToString()
                $l.Items.Add($lvi) | out-null
                if ($initialValue -and $_ -eq $initialValue) {
                    $l.SelectedItem = $lvi
                }
        }
     }
     $l | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
     $l | add-member -MemberType ScriptMethod -Name GetControlValue -Value {$this.SelectedItem} -PassThru
}

function Add-TreeviewContents{
  Param($parent,$items)
    foreach($item in $items){
      if($item -is [Hashtable]){
        foreach($h in ([hashtable]$item).GetEnumerator()){
            $node=New-object TreeViewItem -Property @{Header=$h.Name}
            $Node.Tag=$h.Name
            [void]$parent.Items.Add($node)
            Add-TreeViewContents -parent $Node -items $h.Value
            $node.ExpandSubtree()
        }
      } else {
        $node=New-object TreeViewItem -Property @{Header=$item.ToString()}
        $node.Tag=$item
        $parent.Items.Add($node) | out-null
      }
    }

}
function Treeview {
    Param($name, $contents, $initialValue, $property = @{})
    $baseProperties = @{
        Name = $name
    }
    $properties = Merge-HashTable $baseProperties $property

    $tree = new-object TreeView -Property $properties

    Add-TreeviewContents -parent $tree -items $contents
    $tree | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $tree | add-member -MemberType ScriptMethod -Name GetControlValue -Value {$this.SelectedItem} -PassThru
}
function ComboBox {
    Param($name, $contents, $initialValue, $property = @{})
    $baseProperties = @{
        Name = $name
    }
    $properties = Merge-HashTable $baseProperties $property
    $l = new-object ComboBox -Property $properties
    if ($initialValue) {
        $l.SelectedItem = $initialValue
    }

    $contents | ForEach-Object {$l.Items.Add($_) | out-null }
    $l | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $l | add-member -MemberType ScriptMethod -Name GetControlValue -Value {$this.SelectedItem} -PassThru
}


function CheckBox {
    Param($Name, [Boolean]$InitialValue = $false, $property = @{})
    $baseProperties = @{
        Name      = $name
        Content   = $Name
        IsChecked = $InitialValue
    }
    $properties = Merge-HashTable $baseProperties $property
    $chk = new-object CheckBox -Property $properties
    $chk | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $chk | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.IsChecked} -PassThru
}

function StackPanel{
  Param([Scriptblock]$Contents,$Property=@{},[ValidateSet('Horizontal','Vertical')]$Orientation='Horizontal',$name)
    $baseProperties = @{
        Orientation = [Orientation]$Orientation
    }
    if($name){
      $baseProperties.Name=$name
    }
    $properties = Merge-HashTable $baseProperties $property
    $stack = new-object StackPanel -Property $properties
    [System.Windows.UIElement[]]$c = & $Contents
    $c | foreach-object{    $stack.Children.Add($_) | out-null }
    $stack | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $stack | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$d=@{}
                                                                               $this.Children | ForEach-Object{if($_| get-member GetControlValue){$d.Add($_.Name,$_.GetControlValue())}}
                                                                               if($d.Count -eq 1){
                                                                                 $d.Values| Select-Object -first 1}
                                                                                 else {
                                                                                 [pscustomobject]$d
                                                                               }} -PassThru
}

function Grid{
  Param([Scriptblock]$Contents,$Property=@{},$name,$ColumnCount=1,$RowCount=1)
  $baseProperties = @{}
  if($name){
    $baseProperties.Name=$name
  }
  $properties = Merge-HashTable $baseProperties $property
  $Grid = new-object Grid -Property $properties
  $grid.RowDefinitions.Clear()
  $grid.ColumnDefinitions.Clear()
  1..$RowCount | ForEach-Object { $grid.RowDefinitions.Add( (new-object RowDefinition -Property @{Height='Auto'}))}
  1..$ColumnCount |  ForEach-Object { $grid.ColumnDefinitions.Add((new-object ColumnDefinition -property @{Width='Auto'}))}


  [System.Windows.UIElement[]]$c = & $Contents
  $objectCount=0
  $c | foreach-object{
    $row=[Math]::Truncate($objectCount/ $columnCount)
    $col=$objectCount % $columnCount
    write-host "Adding control '$($_.Name)' at ($col,$row)"
    $Grid.Children.Add($_) | out-null
    [Grid]::SetColumn( $_, $col)
    [Grid]::SetRow($_,$row)
    $objectCount+=1
  }
  $Grid | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
  $Grid | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$d=@{}
    $this.Children | ForEach-Object{if($_| get-member GetControlValue){$d.Add($_.Name,$_.GetControlValue())}}
    if($d.Count -eq 1){
    $d.Values| Select-Object -first 1}
    else {
      [pscustomobject]$d
    }
  } -PassThru
}


function Button {
  Param($Caption,[ScriptBlock]$Action,$property=@{})
    $baseProperties = @{
                                                             Content=$Caption
                                                            }
   $properties = Merge-HashTable $baseProperties $property
   $btn=new-object Button -Property $properties
   $btn | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
   $btn.Add_Click($action)
   $btn
}

function DatePicker {
    Param($Name, [DateTime]$InitialValue = (get-date), $property = @{})
    $baseProperties = @{
        Name = $name
        Text = $InitialValue
    }
    $properties = Merge-HashTable $baseProperties $property
    $dpck = new-object DatePicker -Property $properties
    $dpck | add-member -Name Window -MemberType ScriptProperty -Value {[System.Windows.Window]::GetWindow($this)}
    $dpck | add-member -Name GetControlValue -MemberType ScriptMethod -Value {$this.Text} -PassThru
}
function Invoke-ObjectEditor {
    [CmdletBinding()]
    Param([Parameter(ValueFromPipeline = $true)]$inputobject,
        [string[]]$Property,
        [hashtable]$LabelMap=@{},
        [switch]$Update)

    $Controls = $(
        foreach ($item in $inputObject | get-member -name $property -MemberType Properties) {
            $value = $inputobject.$($item.Name)
            switch ($value.GetType()) {
                'Int32' {TextBox -Name $item.Name -InitialValue $value}
                'String' {TextBox -Name $item.Name -InitialValue $value}
                'bool' {CheckBox -Name $Item.Name -InitialValue $value}
                'DateTime' {TextBox -Name $item.Name -InitialValue $value}
            }
        }
    )

    $out = Dialog {$controls} -LabelMap $labelMap
    if ($update) {
        foreach ($item in $out | get-member $Property -MemberType Properties) {
            $inputobject.$($item.Name) = $out.$($item.Name)
        }
        $inputobject
    } else {
        $out
    }
}
New-Alias -Name Edit-Object -Value Invoke-ObjectEditor

<#
    #example code
    window { TextBox Fred 'hello world'
         TextBox Barney 'hey there!'
         Textbox Bubba 'another textbox'
         Checkbox Wilma 1
         Combobox Betty Able,Baker,Charlie}
#>

function CredentialDialog{
  Param([PSCredential]$username)
  $o=Dialog {Textbox UserName -InitialValue $username.UserName
          Password Password}
  if($o) {
    New-Object System.Management.Automation.PSCredential ($o.UserName, $o.Password )
  }
}